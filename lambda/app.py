"""Lambda: OCR pipeline para PDFs escaneados en S3."""
import os
import json
import subprocess
import tempfile
import boto3
import urllib.parse

s3 = boto3.client("s3")
INPUT_BUCKET = os.environ.get("INPUT_BUCKET", "robotic-paper-rag")
OUTPUT_PREFIX = os.environ.get("OUTPUT_PREFIX", "books/")
INPUT_PREFIX = os.environ.get("INPUT_PREFIX", "raw-scan/")
LANGS = os.environ.get("OCR_LANGS", "spa+eng")
MAX_SIZE_MB = 400


def lambda_handler(event, context):
    for record in event.get("Records", []):
        bucket = record["s3"]["bucket"]["name"]
        key = urllib.parse.unquote_plus(record["s3"]["object"]["key"])
        if not key.lower().endswith(".pdf") or not key.startswith(INPUT_PREFIX):
            continue
        basename = os.path.basename(key)
        size_mb = record["s3"]["object"]["size"] / (1024 * 1024)
        if size_mb > MAX_SIZE_MB:
            continue
        with tempfile.TemporaryDirectory() as tmp:
            local_in = os.path.join(tmp, "input.pdf")
            local_out = os.path.join(tmp, "output.pdf")
            s3.download_file(bucket, key, local_in)
            cmd = [
                "ocrmypdf", "-l", LANGS, "--force-ocr", "--deskew",
                "--clean", "--optimize", "1", "--jobs", "2",
                local_in, local_out,
            ]
            try:
                subprocess.run(cmd, check=True, timeout=900,
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
                continue
            out_key = OUTPUT_PREFIX + os.path.splitext(basename)[0] + "_ocr.pdf"
            s3.upload_file(local_out, bucket, out_key)
            s3.delete_object(Bucket=bucket, Key=key)
    return {"statusCode": 200, "body": json.dumps("OCR completado")}
