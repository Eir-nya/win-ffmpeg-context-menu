import sys, os

os.chdir("D:/Context Menu/FFmpeg/Video")

if __name__ == "__main__":
    os.system("wsl \"./shrink.zsh\" \"" + (sys.argv[1][0].lower() + sys.argv[1].replace("\\", "/")[2:]) + "\"")
