# violet-llm

Qwen3-Embedding-4B experiment over the latest 1,000 numeric files in
`../violet-ocr/raw-merged-v2`.

    cd violet-llm
    python -m venv .venv
    .\.venv\Scripts\Activate.ps1
    # Install CUDA PyTorch appropriate for this PC first.
    python -m pip install -r requirements.txt

    # Prepare latest three works first.
    python prepare.py --work-count 3 --dataset-name smoke-3 --overwrite
    python embed.py --dataset-name smoke-3 --output-name smoke-3 --batch-size 2

    # Full latest 1,000.
    python prepare.py
    python embed.py

    python search.py "your Korean scene query" --top-k 20

The default chunk is a three-page window with a two-page stride. Each stored
chunk retains the source page, dialogue index, confidence, and bbox.
