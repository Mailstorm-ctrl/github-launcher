# github-launcher
Download and run a git repo using SSH.

## Why?
I didn't know or understand how to make scheduled scripts using github as a source. I would create scripts, create a scheduled task, modify the script sometime later and then forget to update the file the scheduled task uses. This helped me avoid that as all I need to do is update the github repo and the scheduled task will now use the latest version all the time.

## How do I use it?
For now, this will only work on Windows. But the ideal method is that you:
1. Have the script(s) or programs you need to run on github in some repo.
2. Download launcher.ps1
3. Create a scheduled task using your own defined timing and triggers
4. Set the program to launch as this script and use the appropriate arguments.

You will also need to setup SSH access to the repo that has the script or program you need to run in. You can read how to do that [here](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent). This currently will not work with public repos. 

Maybe I'll make a seperate script to work with public repos or I'll combine it. Who knows. I'm also wanting to make a full bash/sh version of this script too, but my bash scripting is rusty.
