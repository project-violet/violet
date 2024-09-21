# Violet Server CD Hook

This code is used for github cd webhook

```sh
git clone --filter=blob:none --sparse https://github.com/project-violet/violet
cd violet
git sparse-checkout init --cone
git sparse-checkout set violet-server-hook
cd violet-server-hook
sudo apt install awscli docker
sudo pip3 install gunicorn flask
```

```sh
sudo nohup ./run.sh &
```
