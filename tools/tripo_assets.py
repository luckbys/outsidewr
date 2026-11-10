#!/usr/bin/env python3
"""Generate resumable Tripo v3 assets; the game itself never uses this API key.

Protocol source: the user's quick-start.pdf (text-to-model, tasks, rig-check,
rig and preset:walk retarget). Stdlib only; `plan` never accesses the network.
"""

import argparse
import contextlib
import hashlib
import json
import os
from pathlib import Path
import re
import struct
import sys
import tempfile
import time
import uuid
from urllib.error import HTTPError, URLError
from urllib.parse import quote, urlsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener

PROJECT = Path(__file__).resolve().parents[1]
API_ROOT = "https://openapi.tripo3d.ai/v3"
CATALOG = PROJECT / "tools/tripo_catalog.json"
STATE = PROJECT / "builds/tripo/state.json"
OUTPUT = PROJECT / "assets/models/tripo"
TERMINAL_FAILURES = {"failed", "cancelled", "banned", "expired"}
MAX_MODEL_BYTES = 64 * 1024 * 1024
STAGES = {"generate": "generation/text-to-model", "check": "animations/rig-check",
          "rig": "animations/rig", "walk": "animations/retarget"}


class TripoError(RuntimeError):
    def __init__(self, message, known_rejected=False):
        super().__init__(message)
        self.known_rejected = known_rejected


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, message, headers, newurl):
        return None  # Never forward the API authorization header to another host.


class DownloadRedirect(HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, message, headers, newurl):
        validate_download_url(newurl)
        redirected = super().redirect_request(request, fp, code, message, headers, newurl)
        if redirected is not None:
            redirected.remove_header("Authorization")
        return redirected


def valid_task_id(value):
    try:
        uuid.UUID(value)
        return True
    except (ValueError, TypeError, AttributeError):
        return False


def validate_download_url(url):
    parsed = urlsplit(url)
    if parsed.scheme != "https" or not parsed.hostname or parsed.username or parsed.password or parsed.port not in (None, 443):
        raise TripoError("O endereço do modelo precisa ser HTTPS, sem credenciais na URL.")
    return parsed


def atomic_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")
    os.chmod(temporary, 0o600)
    temporary.replace(path)


def load_catalog(path=CATALOG):
    catalog = json.loads(path.read_text())
    if catalog.get("api_root") != API_ROOT:
        raise TripoError("O catálogo deve usar somente a API oficial da Tripo v3.")
    assets = catalog.get("assets", [])
    ids = [asset.get("id", "") for asset in assets]
    if not ids or len(ids) != len(set(ids)) or any(not re.fullmatch(r"[a-z][a-z0-9_]{1,63}", name) for name in ids):
        raise TripoError("IDs de assets ausentes, repetidos ou inválidos.")
    for asset in assets:
        if not isinstance(asset.get("prompt"), str) or not asset["prompt"].strip():
            raise TripoError("Cada asset precisa de um prompt.")
    return catalog


def validate_glb(path):
    """Reject HTML/error pages, truncated downloads and remote texture references."""
    size = path.stat().st_size
    if size < 20 or size > MAX_MODEL_BYTES:
        raise TripoError("O arquivo GLB está vazio, incompleto ou excede 64 MiB.")
    with path.open("rb") as stream:
        magic, version, length = struct.unpack("<4sII", stream.read(12))
        if magic != b"glTF" or version != 2 or length != size:
            raise TripoError("A resposta não é um arquivo GLB 2.0 completo.")
        chunk_length, chunk_type = struct.unpack("<I4s", stream.read(8))
        if chunk_type != b"JSON" or chunk_length > size - 20:
            raise TripoError("O GLB não possui um cabeçalho JSON válido.")
        try:
            document = json.loads(stream.read(chunk_length))
        except (ValueError, UnicodeDecodeError) as error:
            raise TripoError("JSON inválido no modelo GLB.") from error
        if document.get("asset", {}).get("version") != "2.0" or not document.get("meshes"):
            raise TripoError("O GLB precisa conter uma malha glTF 2.0.")
        for item in document.get("buffers", []) + document.get("images", []):
            uri = item.get("uri", "")
            if uri and not uri.startswith("data:"):
                raise TripoError("O GLB usa arquivos externos; exporte com texturas e buffers incorporados.")
    return hashlib.sha256(path.read_bytes()).hexdigest()


class Client:
    def __init__(self, key=None, opener=None, sleep=time.sleep, now=time.monotonic):
        configured = os.environ.get("TRIPO_API_KEY") or os.environ.get("triploapi", "")
        self.key = (key if key is not None else configured).strip()
        if not self.key:
            raise TripoError("TRIPO_API_KEY ausente (ou alias triploapi). Cadastre a chave nas configurações secretas do ambiente; não a coloque no chat ou no repositório.")
        self.opener = opener or build_opener(NoRedirect())
        self.download_opener = build_opener(DownloadRedirect())
        self.sleep, self.now, self.last_request = sleep, now, None

    def request(self, method, path, body=None):
        if self.last_request is not None:
            delay = 1.1 - (self.now() - self.last_request)
            if delay > 0:
                self.sleep(delay)
        self.last_request = self.now()
        request = Request(API_ROOT + "/" + path, method=method,
                          data=json.dumps(body).encode() if body is not None else None,
                          headers={"Authorization": "Bearer " + self.key,
                                   "Content-Type": "application/json", "Accept": "application/json"})
        try:
            with self.opener.open(request, timeout=30) as response:
                payload = json.loads(response.read(2 * 1024 * 1024))
        except HTTPError as error:
            # Deliberately omit response bodies, headers, signed URLs and the key.
            try:
                provider_error = json.loads(error.read(4096))
                provider_code = provider_error.get("code") if isinstance(provider_error, dict) else None
            except (ValueError, OSError):
                provider_code = None
            if provider_code == 2010:
                raise TripoError("Créditos insuficientes na conta Tripo (HTTP %d, code=2010). A operação foi recusada; disponibilize créditos na conta da API para retomar." % error.code,
                                 known_rejected=True) from None
            rejected = error.code in {400, 401, 402, 403, 404, 405, 413, 415, 422, 429}
            raise TripoError("Tripo respondeu HTTP %d em %s. Verifique acesso, chave e saldo no painel." % (error.code, path.split("/")[0]), known_rejected=rejected) from None
        except (URLError, TimeoutError, OSError) as error:
            raise TripoError("Não foi possível conectar a openapi.tripo3d.ai (%s)." % type(error).__name__) from None
        except (ValueError, UnicodeDecodeError):
            raise TripoError("A Tripo devolveu uma resposta JSON inválida.") from None
        if not isinstance(payload, dict) or payload.get("code") != 0 or not isinstance(payload.get("data"), dict):
            code = payload.get("code") if isinstance(payload, dict) else None
            code = code if type(code) is int else "inválido"
            raise TripoError("A API rejeitou a operação (code=%s). Consulte o painel Tripo." % code,
                             known_rejected=type(code) is int and code != 0)
        return payload["data"]

    def create(self, stage, body):
        result = self.request("POST", STAGES[stage], body)
        task_id = result.get("task_id", "")
        if not valid_task_id(task_id):
            raise TripoError("A API não retornou um task_id válido; a submissão precisa ser conferida no painel.")
        return task_id

    def poll(self, task_id, timeout, report=print):
        deadline = self.now() + timeout
        previous = None
        while self.now() < deadline:
            result = self.request("GET", "tasks/" + quote(task_id, safe=""))
            status = result.get("status")
            safe_status = status if status in {"queued", "pending", "running", "processing", "success"} | TERMINAL_FAILURES else "aguardando"
            progress = result.get("progress")
            progress = min(100, max(0, progress)) if type(progress) in (int, float) else "?"
            current = (safe_status, progress)
            if current != previous:
                report("  %s / %s%%" % current)
                previous = current
            if status == "success":
                return result
            if status in TERMINAL_FAILURES:
                raise TripoError("A tarefa terminou com status %s; não será gerada outra automaticamente." % status)
            self.sleep(2)
        raise TripoError("Tempo de espera esgotado. Execute o mesmo comando para retomar o task_id existente.")

    def download(self, url, destination):
        parsed = validate_download_url(url)
        destination.parent.mkdir(parents=True, exist_ok=True)
        temporary = None
        try:
            # A separate opener and request carry NO API Authorization to the CDN.
            with self.download_opener.open(Request(url, headers={"Accept": "model/gltf-binary,application/octet-stream"}), timeout=60) as response:
                if int(response.headers.get("Content-Length", "0")) > MAX_MODEL_BYTES:
                    raise TripoError("Modelo acima do limite de 64 MiB.")
                with tempfile.NamedTemporaryFile(dir=destination.parent, suffix=".part", delete=False) as stream:
                    temporary = Path(stream.name)
                    total = 0
                    while chunk := response.read(64 * 1024):
                        total += len(chunk)
                        if total > MAX_MODEL_BYTES:
                            raise TripoError("Modelo acima do limite de 64 MiB.")
                        stream.write(chunk)
            checksum = validate_glb(temporary)
            os.chmod(temporary, 0o644)
            temporary.replace(destination)
            return checksum
        except HTTPError as error:
            raise TripoError("Download HTTP %d em %s. Confira a liberação desse domínio; URLs de modelos expiram após 5 minutos." % (error.code, parsed.hostname)) from None
        except (URLError, TimeoutError, OSError):
            raise TripoError("Falha ao baixar o modelo de %s; retome a tarefa para obter o resultado novamente." % parsed.hostname) from None
        finally:
            if temporary is not None:
                temporary.unlink(missing_ok=True)


class Pipeline:
    def __init__(self, client, catalog, state_path=STATE, output=OUTPUT, report=print):
        self.client, self.catalog = client, catalog
        self.state_path, self.output, self.report = state_path, output, report
        self.state = json.loads(state_path.read_text()) if state_path.exists() else {"version": 1, "assets": {}}

    def save(self):
        atomic_json(self.state_path, self.state)

    def body(self, asset, stage, previous=None):
        if stage == "generate":
            return {"prompt": asset["prompt"], "model": self.catalog["model"],
                    "face_limit": self.catalog["face_limit"], "texture": self.catalog["texture"]}
        if stage == "rig":
            return {"input": previous, "model": self.catalog["rig_model"], "rig_type": "biped", "spec": "mixamo"}
        if stage == "walk":
            return {"input": previous, "animation": "preset:walk"}
        return {"input": previous}

    def run(self, asset, timeout=600):
        fingerprint = hashlib.sha256(json.dumps({"asset": asset, "model": self.catalog["model"],
            "rig_model": self.catalog["rig_model"], "face_limit": self.catalog["face_limit"],
            "texture": self.catalog["texture"]}, sort_keys=True).encode()).hexdigest()
        record = self.state["assets"].setdefault(asset["id"], {"fingerprint": fingerprint, "stages": {}})
        if record.get("fingerprint") != fingerprint:
            raise TripoError("O prompt ou a configuração de %s mudou. Use outro ID ou outro --state para um novo lote." % asset["id"])
        final_path = self.output / (asset["id"] + ".glb")
        if final_path.exists():
            if record.get("sha256") and validate_glb(final_path) == record["sha256"]:
                self.report(asset["id"] + ": já baixado e validado; nenhuma nova tarefa.")
                return
            raise TripoError("%s já existe e não corresponde a este lote. O arquivo não foi substituído." % final_path)
        stages = ["generate", "check", "rig", "walk"] if asset["animate"] else ["generate"]
        previous = None
        for stage in stages:
            step = record["stages"].get(stage)
            if step is not None and step.get("status") == "rejected":
                step = None  # An explicit new command can retry a rejected request.
            if step is None:
                # Save BEFORE POST. A timeout/crash after acceptance must never
                # silently bill a second task when this command is resumed.
                step = {"status": "submission_unknown"}
                record["stages"][stage] = step
                self.save()
                self.report("%s / %s: submetendo à Tripo" % (asset["id"], stage))
                try:
                    step["task_id"] = self.client.create(stage, self.body(asset, stage, previous))
                except TripoError as error:
                    if error.known_rejected:
                        step["status"] = "rejected"
                        self.save()
                    raise
                step["status"] = "submitted"
                self.save()
            if not step.get("task_id"):
                raise TripoError("Submissão de %s/%s sem task_id confirmado. Confira o painel e use adopt; não haverá POST duplicado." % (asset["id"], stage))
            task_id = step["task_id"]
            if stage != stages[-1] and step.get("status") == "success":
                if stage != "check":
                    previous = task_id
                continue
            self.report("%s / %s / tarefa %s" % (asset["id"], stage, task_id))
            result = self.client.poll(task_id, timeout, self.report)
            output = result.get("output", {})
            if stage == "check":
                if output.get("riggable") is not True or output.get("rig_type") != "biped":
                    raise TripoError("%s não passou no rig-check bípede. O modelo original foi preservado; não haverá regeneração automática." % asset["id"])
                # Rig takes the ORIGINAL generation task, not the check task.
            else:
                is_final = stage == stages[-1]
                destination = final_path if is_final else self.state_path.parent / "sources" / (asset["id"] + "-" + stage + ".glb")
                url = output.get("model_url")
                if not url and is_final:
                    raise TripoError("A tarefa foi concluída sem output.model_url.")
                if url:
                    checksum = self.client.download(url, destination)
                    if is_final:
                        record["sha256"] = checksum
                    step["downloaded"] = True
                previous = task_id
            step["status"] = "success"
            self.save()  # Never persist the short-lived signed download URLs.
        self.report("%s: GLB validado em %s" % (asset["id"], final_path))


@contextlib.contextmanager
def state_lock(path):
    import fcntl
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.with_suffix(".lock").open("a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise TripoError("Outro processo está usando este lote; nenhuma tarefa foi criada.") from None
        yield


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["plan", "generate", "status", "adopt"])
    selection = parser.add_mutually_exclusive_group()
    selection.add_argument("--asset", action="append", default=[], help="ID do asset; pode ser repetido")
    selection.add_argument("--all", action="store_true", help="Selecionar o lote inteiro de oito modelos")
    parser.add_argument("--state", type=Path, default=STATE)
    parser.add_argument("--timeout", type=int, default=600, help="Limite por tarefa, em segundos")
    parser.add_argument("--stage", choices=STAGES)
    parser.add_argument("--task-id", help="Task ID existente para resolver uma submissão sem resposta")
    args = parser.parse_args(argv)
    try:
        catalog = load_catalog()
        selected = [a for a in catalog["assets"] if args.all or not args.asset or a["id"] in args.asset]
        unknown = set(args.asset) - {a["id"] for a in catalog["assets"]}
        if unknown:
            raise TripoError("Assets desconhecidos: " + ", ".join(sorted(unknown)))
        if args.command == "plan":
            for asset in selected:
                print("%-18s %s%s" % (asset["id"], asset["label"], " + rig-check / rig / walk" if asset["animate"] else ""))
            tasks = sum(4 if a["animate"] else 1 for a in selected)
            print("%d modelos / até %d tarefas; modelo %s; face_limit=%d. Sem chamadas de API." %
                  (len(selected), tasks, catalog["model"], catalog["face_limit"]))
            print("O PDF não informa o custo em créditos; consulte os valores da sua conta Tripo.")
            return 0
        if args.command == "status":
            state = json.loads(args.state.read_text()) if args.state.exists() else {"assets": {}}
            for asset in selected:
                record = state["assets"].get(asset["id"], {})
                print(asset["id"], "concluído" if record.get("sha256") else "pendente", json.dumps(record.get("stages", {})))
            return 0
        if args.command == "adopt":
            if len(args.asset) != 1 or not args.stage or not valid_task_id(args.task_id):
                raise TripoError("Use adopt --asset ID --stage ETAPA --task-id TASK_ID existente.")
            with state_lock(args.state):
                state = json.loads(args.state.read_text())
                step = state["assets"][args.asset[0]]["stages"][args.stage]
                if step.get("task_id"):
                    raise TripoError("A etapa já tem task_id; execute generate para retomá-la.")
                step.update(task_id=args.task_id, status="submitted")
                atomic_json(args.state, state)
            return 0
        if not args.asset and not args.all:
            raise TripoError("Selecione explicitamente --asset ID ou --all antes de gerar modelos pagos.")
        if args.timeout < 2:
            raise TripoError("--timeout precisa ser de pelo menos 2 segundos por tarefa.")
        client = Client()
        with state_lock(args.state):
            pipeline = Pipeline(client, catalog, args.state)
            for asset in selected:
                pipeline.run(asset, args.timeout)
        print("Importe os GLBs no Godot: bash tools/setup.sh. A chave não é necessária para jogar ou publicar.")
        return 0
    except (TripoError, ValueError, KeyError, OSError) as error:
        # Don't output repr(request), traceback locals or provider response bodies.
        print("Erro:", str(error), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
