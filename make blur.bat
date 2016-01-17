(xcc -target=XC-1A -g -o blur.xe blur.xc > nul
) && xrun --io blur.xe
