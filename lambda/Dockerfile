FROM public.ecr.aws/lambda/python:3.11

RUN dnf install -y \
    tesseract \
    tesseract-langpack-spa \
    tesseract-langpack-eng \
    ghostscript \
    qpdf \
    unpaper \
    pngquant \
    && dnf clean all

RUN pip install --no-cache-dir ocrmypdf==15.4.2

COPY app.py ${LAMBDA_TASK_ROOT}/

CMD [ "app.lambda_handler" ]
