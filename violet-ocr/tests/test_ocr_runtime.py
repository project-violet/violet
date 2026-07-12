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
    def test_merge_existing_dialogues_stacks_overlapping_lines(self):
        from adjust_raw_dialogues import merge_page_dialogues

        page = {
            "width": 1000,
            "height": 1500,
            "dialogues": [
                {"text": "나는", "confidence": 0.98, "bbox": [100, 100, 260, 140]},
                {"text": "나비다", "confidence": 0.96, "bbox": [80, 150, 300, 190]},
            ],
        }

        merged = merge_page_dialogues(page)

        self.assertEqual(len(merged), 1)
        self.assertEqual(merged[0]["text"], "나는\n나비다")
        self.assertEqual(merged[0]["bbox"], [80, 100, 300, 190])
        self.assertEqual(merged[0]["mergeMeta"]["sourceDialogueIndices"], [0, 1])

    def test_merge_existing_dialogues_joins_close_same_line_fragments(self):
        from adjust_raw_dialogues import merge_page_dialogues

        page = {
            "width": 1000,
            "height": 1500,
            "dialogues": [
                {"text": "안녕", "confidence": 0.9, "bbox": [100, 100, 250, 140]},
                {"text": "하세요", "confidence": 0.8, "bbox": [254, 102, 420, 142]},
            ],
        }

        merged = merge_page_dialogues(page)

        self.assertEqual(len(merged), 1)
        self.assertEqual(merged[0]["text"], "안녕 하세요")

    def test_merge_existing_dialogues_keeps_close_multiline_bubbles_apart(self):
        from adjust_raw_dialogues import merge_page_dialogues

        page = {
            "width": 708,
            "height": 1000,
            "dialogues": [
                {
                    "text": "좋아! 사정은 이해했다! 바라는 대로 해주지!",
                    "confidence": 0.9,
                    "bbox": [11, 367, 129, 442],
                },
                {"text": "아라가키 아야세를 범해주세요", "confidence": 0.9, "bbox": [146, 395, 221, 448]},
            ],
        }

        merged = merge_page_dialogues(page)

        self.assertEqual(len(merged), 2)

    def test_merge_existing_dialogues_stops_after_terminal_punctuation(self):
        from adjust_raw_dialogues import merge_page_dialogues

        page = {
            "width": 720,
            "height": 4995,
            "dialogues": [
                {"text": "그럼 이렇게 생각하시는 건 어때요?", "confidence": 0.9, "bbox": [73, 1488, 270, 1618]},
                {"text": "한초연씨의 팬이 드리는 선물로", "confidence": 0.9, "bbox": [113, 1634, 326, 1769]},
            ],
        }

        merged = merge_page_dialogues(page)

        self.assertEqual(len(merged), 2)

    def test_merge_existing_dialogues_does_not_join_heavily_overlapping_detections(self):
        from adjust_raw_dialogues import merge_page_dialogues

        page = {
            "width": 1000,
            "height": 1500,
            "dialogues": [
                {"text": "기획안", "confidence": 0.9, "bbox": [100, 100, 400, 220]},
                {"text": "기획안 중복", "confidence": 0.8, "bbox": [120, 110, 390, 210]},
            ],
        }

        merged = merge_page_dialogues(page)

        self.assertEqual(len(merged), 2)

    def test_merge_existing_dialogues_keeps_separate_bubbles_apart(self):
        from adjust_raw_dialogues import merge_page_dialogues

        page = {
            "width": 1000,
            "height": 1500,
            "dialogues": [
                {"text": "왼쪽", "confidence": 0.9, "bbox": [80, 100, 220, 150]},
                {"text": "오른쪽", "confidence": 0.9, "bbox": [600, 105, 760, 155]},
                {"text": "큰 제목", "confidence": 0.9, "bbox": [70, 180, 360, 300]},
            ],
        }

        merged = merge_page_dialogues(page)

        self.assertEqual([item["text"] for item in merged], ["왼쪽", "오른쪽", "큰 제목"])

    def test_merge_existing_dialogues_does_not_chain_distant_stacked_bubbles(self):
        from adjust_raw_dialogues import merge_page_dialogues

        page = {
            "width": 1280,
            "height": 1800,
            "dialogues": [
                {"text": "첫 번째 말풍선", "confidence": 0.9, "bbox": [100, 100, 300, 160]},
                {"text": "두 번째 말풍선", "confidence": 0.9, "bbox": [110, 215, 310, 275]},
                {"text": "세 번째 말풍선", "confidence": 0.9, "bbox": [105, 330, 305, 390]},
            ],
        }

        merged = merge_page_dialogues(page)

        self.assertEqual(
            [item["text"] for item in merged],
            ["첫 번째 말풍선", "두 번째 말풍선", "세 번째 말풍선"],
        )

    def test_merge_existing_dialogues_caps_a_group_at_four_sources(self):
        from adjust_raw_dialogues import merge_page_dialogues

        page = {
            "width": 1000,
            "height": 1500,
            "dialogues": [
                {"text": str(i), "confidence": 0.9, "bbox": [100 + i * 154, 100, 250 + i * 154, 140]}
                for i in range(5)
            ],
        }

        merged = merge_page_dialogues(page)

        self.assertEqual(len(merged), 2)
        self.assertLessEqual(
            max(len(item.get("mergeMeta", {}).get("sourceDialogueIndices", [0])) for item in merged),
            4,
        )

    def test_merge_existing_dialogues_uses_nearby_credit_boxes_as_a_barrier(self):
        from adjust_raw_dialogues import merge_page_dialogues

        page = {
            "width": 725,
            "height": 1024,
            "dialogues": [
                {"text": "굴할까", "confidence": 0.9, "bbox": [196, 678, 436, 763]},
                {"text": "/", "confidence": 0.9, "bbox": [162, 697, 195, 730]},
                {"text": "Presented by", "confidence": 0.9, "bbox": [454, 698, 606, 709]},
                {
                    "text": "쓸데없다고 생각하신다면 정말 그런지 한번 사용해보시지 않겠습니까?",
                    "confidence": 0.9,
                    "bbox": [228, 805, 313, 938],
                },
            ],
        }

        merged = merge_page_dialogues(page)

        self.assertEqual(
            [item["text"] for item in merged],
            ["굴할까", "/", "Presented by", "쓸데없다고 생각하신다면 정말 그런지 한번 사용해보시지 않겠습니까?"],
        )

    def test_merge_existing_dialogues_does_not_absorb_slash_credit_text(self):
        from adjust_raw_dialogues import merge_page_dialogues

        page = {
            "width": 725,
            "height": 1024,
            "dialogues": [
                {"text": "첨단과학에", "confidence": 0.9, "bbox": [83, 605, 437, 693]},
                {"text": "이역/식", "confidence": 0.9, "bbox": [435, 594, 615, 649]},
            ],
        }

        merged = merge_page_dialogues(page)

        self.assertEqual([item["text"] for item in merged], ["이역/식", "첨단과학에"])

    def test_merge_existing_dialogues_does_not_append_latin_credit_to_korean(self):
        from adjust_raw_dialogues import merge_page_dialogues

        page = {
            "width": 1280,
            "height": 1868,
            "dialogues": [
                {"text": "바주는 건 여기까지", "confidence": 0.9, "bbox": [15, 1105, 895, 1249]},
                {"text": "yB", "confidence": 0.9, "bbox": [893, 1162, 1185, 1263]},
            ],
        }

        merged = merge_page_dialogues(page)

        self.assertEqual(len(merged), 2)

    def test_merge_existing_dialogues_keeps_two_long_stacked_speeches_apart(self):
        from adjust_raw_dialogues import merge_page_dialogues

        page = {
            "width": 720,
            "height": 5000,
            "dialogues": [
                {
                    "text": "거기에 후가 이길 시엔 특별한 것도 아니라 그저 이번 일에 대해 후를 믿고 따라 달라",
                    "confidence": 0.9,
                    "bbox": [34, 4141, 332, 4318],
                },
                {
                    "text": "너무 쉬운 거 아니야? 후도 알잖아 내가 언제나 후를 믿고 사랑하는 거",
                    "confidence": 0.9,
                    "bbox": [11, 4349, 309, 4516],
                },
            ],
        }

        merged = merge_page_dialogues(page)

        self.assertEqual(len(merged), 2)

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
