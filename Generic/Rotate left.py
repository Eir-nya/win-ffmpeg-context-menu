import sys, os

if __name__ == "__main__":
    splitext = os.path.splitext(sys.argv[1])
    os.system("ffmpeg -y -i \"" + sys.argv[1] + "\" -vf \"transpose=2\" \"" + splitext[0] + "_l" + splitext[1] + "\"")
