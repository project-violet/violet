import os
import sys
import tempfile
import unittest
import importlib.util
import json
import sqlite3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))


def load_run_works_turbo():
    spec = importlib.util.spec_from_file_location(
        "run_works_turbo", ROOT / "run-works-turbo.py"
    )
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


class OcrRuntimeTests(unittest.TestCase):
    def test_group_into_dialogues_merges_nearby_text(self):
        from ocr_common import group_into_dialogues

        texts = [
            {"text": "hello", "confidence": 0.9, "bbox": [10, 10, 30, 20]},
            {"text": "world", "confidence": 0.8, "bbox": [12, 24, 34, 34]},
            {"text": "far", "confidence": 0.7, "bbox": [500, 500, 520, 520]},
        ]

        dialogues = group_into_dialogues(texts, 800, 800)

        self.assertEqual(dialogues[0]["text"], "hello world")
        self.assertEqual(dialogues[0]["bbox"], [10, 10, 34, 34])
        self.assertEqual(dialogues[1]["text"], "far")

    def test_bootstrap_uses_existing_download_without_download(self):
        from work_plan import bootstrap_work_plan, load_expected_file_counts

        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            image_dir = tmp_path / "tmp" / "123"
            image_dir.mkdir(parents=True)
            (image_dir / "0001.webp").write_bytes(b"fake")
            args = type(
                "Args",
                (),
                {
                    "raw_dir": str(tmp_path / "raw"),
                    "tmp_dir": str(tmp_path / "tmp"),
                    "keep_empty_tmp": False,
                    "force_ocr": False,
                    "force_download": False,
                    "max_pages": 500,
                    "retry_failed": True,
                    "failed_ids": str(tmp_path / "works" / "failed_ids.jsonl"),
                },
            )()

            self.assertEqual(load_expected_file_counts(str(tmp_path / "missing.db"), ["123"]), {})
            plan = bootstrap_work_plan(["123"], args, {"123": 1})

        self.assertEqual(plan.download_ids, [])
        self.assertEqual(len(plan.existing_downloads), 1)
        self.assertEqual(plan.existing_downloads[0].work_id, "123")

    def test_refresh_target_ids_uses_korean_existing_hitomi_rows_with_files(self):
        from work_plan import refresh_target_ids

        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            db_path = tmp_path / "data.db"
            target_path = tmp_path / "target_ids.json"
            con = sqlite3.connect(db_path)
            try:
                con.execute(
                    """
                    create table HitomiColumnModel (
                        Id integer primary key,
                        Language text,
                        ExistOnHitomi integer,
                        Files integer
                    )
                    """
                )
                con.executemany(
                    """
                    insert into HitomiColumnModel (Id, Language, ExistOnHitomi, Files)
                    values (?, ?, ?, ?)
                    """,
                    [
                        (30, "korean", 1, 5),
                        (10, "korean", 1, 1),
                        (20, "english", 1, 3),
                        (40, "korean", 0, 4),
                        (50, "korean", 1, 0),
                    ],
                )
                con.commit()
            finally:
                con.close()

            ids = refresh_target_ids(str(target_path), str(db_path))

            self.assertEqual(ids, [10, 30])
            self.assertEqual(json.loads(target_path.read_text(encoding="utf-8")), [10, 30])

    def test_fast_dl_runner_builds_go_command(self):
        from fast_dl_runner import build_fast_dl_command

        cmd = build_fast_dl_command(
            go_downloader="..\\fast-dl\\fast-dl.exe",
            work_id="123",
            output_root="tmp",
            gallery_dl="gallery-dl",
            file_workers=16,
            file_retries=5,
            max_pages=200,
        )

        self.assertEqual(cmd[0], "..\\fast-dl\\fast-dl.exe")
        self.assertIn("-download-work", cmd)
        self.assertIn("123", cmd)
        self.assertIn("-tmp-dir", cmd)
        self.assertIn("tmp", cmd)
        self.assertNotIn("-gallery-dl", cmd)

    def test_busy_default_port_prefers_existing_alternate_container_before_new_port(self):
        module = load_run_works_turbo()
        args = type(
            "Args",
            (),
            {
                "turboocr_url_explicit": False,
                "turboocr_url": "http://localhost:8000",
                "turboocr_container": module.DEFAULT_TURBOOCR_CONTAINER,
            },
        )()

        original_server_ready = module.server_ready
        original_tcp_port_in_use = module.tcp_port_in_use
        original_tcp_port_available = module.tcp_port_available
        original_find_ready_alternate_server = module.find_ready_alternate_server
        original_find_available_port = module.find_available_port
        original_shutil_which = module.shutil.which
        original_docker_container_exists = module._docker_container_exists
        try:
            module.server_ready = lambda url, timeout=2.0: False
            module.tcp_port_in_use = lambda host, port: port == 8000
            module.tcp_port_available = lambda host, port: port != 8000
            module.find_ready_alternate_server = lambda scheme, start: None
            module.find_available_port = lambda start: 18001
            module.shutil.which = lambda name: "docker" if name == "docker" else None
            module._docker_container_exists = (
                lambda docker, name: name == "violet-turboocr-18000"
            )

            module.maybe_rewrite_default_turboocr_port(args)
        finally:
            module.server_ready = original_server_ready
            module.tcp_port_in_use = original_tcp_port_in_use
            module.tcp_port_available = original_tcp_port_available
            module.find_ready_alternate_server = original_find_ready_alternate_server
            module.find_available_port = original_find_available_port
            module.shutil.which = original_shutil_which
            module._docker_container_exists = original_docker_container_exists

        self.assertEqual(args.turboocr_url, "http://localhost:18000")
        self.assertEqual(args.turboocr_container, "violet-turboocr-18000")


if __name__ == "__main__":
    unittest.main()
