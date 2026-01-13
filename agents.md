## Project Goal

write a Dockerfile to:

- base on ubuntu image
- install brew and then use brew to install pyenv
- use pyenv install python 3.14.2
- install GitHub Copilot CLI using brew, refer to this page for more information on how: <https://formulae.brew.sh/cask/copilot-cli>
- install commonly used shell utilities like wget, curl, git, vim, htop, tree, jq, etc.
- install modern commonly used shell utilities like fzf, bat, ripgrep, exa, fd, etc.

Try to build the image and fix any errors you met. This webpage is probably useful for you when install python with pyenv because python has a lot of dependencies when building:<https://github.com/pyenv/pyenv/wiki>. Enable performance optimization flags as well.

A GitHub workflow file to build the Docker image is also required. The created Docker image should be pushed to GitHub Container Registry, use the branch name as the image tag.
