import sys, os

if __name__ == "__main__":
    os.system("ffmpeg -y -i \"" + sys.argv[1] + "\" \"" + os.path.splitext(sys.argv[1])[0] + ".webm" + "\"")
