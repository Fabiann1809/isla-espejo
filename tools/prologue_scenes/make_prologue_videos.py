"""Renders the four prologue scenes and encodes them as Ogg Theora for Godot.

    python tools/prologue_scenes/make_prologue_videos.py            # all four scenes
    python tools/prologue_scenes/make_prologue_videos.py 3 4        # only scenes 3 and 4

Needs Python with numpy and Pillow, and ffmpeg (with libtheora) in the PATH. The animations are drawn by the
make_scene*.py scripts next to this one into builds/prologue/ (ignored by git); the videos go to
assets/video/prologue/, which is what scenes/ui/prologue.tscn plays. Each GIF is retimed to its real frame rate
(scene 1 is 20 fps, the others 30) and every video is 480x270 at 30 fps.
"""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
BUILD = os.path.join(ROOT, "builds", "prologue")
VIDEOS = os.path.join(ROOT, "assets", "video", "prologue")

# scene number -> (script, gif it writes, video name, fps the gif was drawn at)
SCENES = {
    1: ("make_scene1.py", "scene1_storm.gif", "01_tormenta", 20),
    2: ("make_scene2_v2.py", "scene2_wake_v3.gif", "02_despertar", 30),
    3: ("make_scene3_v7.py", "scene3_compass_v7.gif", "03_brujula", 30),
    4: ("make_scene4.py", "scene4_island.gif", "04_isla", 30),
}
QUALITY = "6"       # libtheora quality 0-10: 6 keeps the pixel art clean at about 3 MB per scene


def main() -> None:
    wanted = [int(a) for a in sys.argv[1:]] or sorted(SCENES)
    os.makedirs(BUILD, exist_ok=True)
    os.makedirs(VIDEOS, exist_ok=True)
    for number in wanted:
        script, gif, name, fps = SCENES[number]
        print("scene %d: drawing %s" % (number, script))
        subprocess.run([sys.executable, os.path.join(HERE, script)], check=True, env={**os.environ, "PROLOGUE_OUT": BUILD})
        print("scene %d: encoding %s.ogv" % (number, name))
        subprocess.run([
            "ffmpeg", "-v", "error", "-y", "-i", os.path.join(BUILD, gif),
            "-vf", "setpts=N/(%d*TB),scale=480:270:flags=neighbor" % fps,
            "-r", "30", "-c:v", "libtheora", "-q:v", QUALITY, "-pix_fmt", "yuv444p",
            os.path.join(VIDEOS, name + ".ogv"),
        ], check=True)
    print("done: the videos are in", VIDEOS)


if __name__ == "__main__":
    main()
