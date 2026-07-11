# Violet

Violet is a personal toolkit for collecting manga content, running OCR, building search indexes, analyzing keyword graphs, and serving a web viewer.

## Docker

To deploy without cloning the repository, download the required data files from
[Google Drive](https://drive.google.com/drive/folders/1z0iNhS5Z_SJsAewnZTzOefx2o8-Ug1gY?hl=ko) and place them in a data folder:

```sh
curl -fsSL https://raw.githubusercontent.com/project-violet/violet/main/deploy.sh | VIOLET_DATA_ROOT=/srv/violet-data sh
```

See [DOCKER.md](DOCKER.md) for data layout and local development commands.
