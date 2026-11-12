"""Focused integration tests for animated GIF scene conversion."""

import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from moviepy import VideoFileClip
from PIL import Image

from app.services import video


class TestGifSceneConversion(unittest.TestCase):
    def _make_gif(self, path: Path) -> None:
        frames = [
            Image.new("RGB", (480, 480), (255, 0, 0)),
            Image.new("RGB", (480, 480), (0, 0, 255)),
            Image.new("RGB", (480, 480), (0, 255, 0)),
        ]
        frames[0].save(
            path,
            format="GIF",
            save_all=True,
            append_images=frames[1:],
            duration=[120, 240, 360],
            loop=0,
            disposal=2,
        )

    def test_gif_converts_to_playable_mp4_and_preserves_timing(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            gif_path = Path(temp_dir, "scene.gif")
            self._make_gif(gif_path)

            mp4_path = Path(video._convert_gif_to_video(str(gif_path)))
            self.assertTrue(mp4_path.is_file())
            self.assertGreater(mp4_path.stat().st_size, 0)
            self.assertEqual(mp4_path.parent, gif_path.parent)

            with VideoFileClip(str(mp4_path)) as clip:
                self.assertEqual(tuple(clip.size), (480, 480))
                self.assertGreaterEqual(clip.duration, 0.65)
                self.assertLessEqual(clip.duration, 0.9)
                self.assertGreaterEqual(clip.fps, 2)

    def test_identical_gif_reuses_cached_mp4_without_running_ffmpeg(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            gif_path = Path(temp_dir, "scene.gif")
            self._make_gif(gif_path)
            first_output = video._convert_gif_to_video(str(gif_path))

            with patch.object(
                video.subprocess,
                "run",
                side_effect=AssertionError("cached conversion should not invoke FFmpeg"),
            ):
                second_output = video._convert_gif_to_video(str(gif_path))

            self.assertEqual(first_output, second_output)
            self.assertTrue(Path(second_output).is_file())

    def test_failed_conversion_removes_temporary_output(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            gif_path = Path(temp_dir, "scene.gif")
            self._make_gif(gif_path)

            class FailedProcess:
                returncode = 1
                stderr = "simulated FFmpeg failure"

            with patch.object(
                video.subprocess, "run", return_value=FailedProcess()
            ):
                with self.assertRaisesRegex(RuntimeError, "simulated FFmpeg failure"):
                    video._convert_gif_to_video(str(gif_path))

            self.assertEqual([item.name for item in Path(temp_dir).iterdir()], ["scene.gif"])


if __name__ == "__main__":
    unittest.main()
