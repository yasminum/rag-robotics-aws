# Arquitectura del RAG

## Diagrama

```mermaid
flowchart TB
    subgraph Ingesta["🔄 Pipeline de Ingesta (este repo)"]
        A1[Scraper arXiv<br/>01_scrape_bibliografia.py]
        A2[OCR EC2 Free Tier<br/>02_setup_ec2_ocr.sh + 03_pipeline_ocr.sh]
        A3[Upload S3<br/>04_upload_s3.sh]
        A4[Lambda OCR<br/>trigger automático - opcional]
    end

    subgraph Storage["☁️ AWS Storage"]
        B1[S3 raw-scan/<br/>PDFs escaneados]
        B2[S3 books/<br/>PDFs con OCR]
        B3[S3 papers/<br/>arXiv open access]
        B4[S3 classroom/<br/>Apuntes DOCX/PPTX]
    end

    subgraph Bedrock["🤖 Amazon Bedrock"]
        C1[Knowledge Base]
        C2[Titan Text Embeddings V2<br/>1024 dimensiones]
        C3[Claude 3.5 Sonnet<br/>LLM generador]
    end

    subgraph VectorStore["🔢 Vector Store"]
        D1[(S3 Vectors<br/>más barato)]
        D2[(OpenSearch Serverless<br/>alternativa)]
    end

    subgraph User["👤 Usuario"]
        E1[Pregunta en lenguaje natural]
        E2[Respuesta citada]
    end

    A1 --> B3
    A2 --> B2
    A3 --> B2
    A3 --> B3
    A3 --> B4
    A4 --> B2

    B2 --> C1
    B3 --> C1
    B4 --> C1

    C1 --> C2
    C2 --> D1
    C2 -.-> D2

    E1 --> C1
    C1 --> C3
    C3 --> E2
```

## Componentes

### 1. Pipeline de ingesta (este repositorio)

| Script | Función |
|---|---|
| `01_scrape_bibliografia.py` | Descarga legalmente papers de arXiv (CLIP, SayCan, RT-2, PaLM-E) |
| `02_setup_ec2_ocr.sh` | Instala OCRmyPDF + Tesseract español en EC2 Amazon Linux 2023 |
| `03_pipeline_ocr.sh` | Corre OCR en batch sobre todos los PDFs de `raw-scan/` |
| `04_upload_s3.sh` | Sube a S3 sanitizando nombres (sin espacios/acentos/paréntesis) |
| `lambda/app.py` | Alternativa serverless: OCR automático en cada upload a `raw-scan/` |

### 2. Storage (S3)

- `raw-scan/` — PDFs escaneados pendientes de OCR
- `books/` — PDFs con texto seleccionable (originales + OCR)
- `papers/` — Papers de arXiv (open access)
- `classroom/` — Apuntes, diapositivas, código MATLAB exportado a PDF

### 3. Bedrock Knowledge Base

- **Embeddings**: Titan Text Embeddings V2 (1024 dims, $0.0001/1K tokens)
- **LLM**: Claude 3.5 Sonnet v2 (consultas RAG)
- **Chunking**: Default (300 tokens, 20% overlap)

### 4. Vector Store

- **Recomendado**: S3 Vectors (nuevo 2025, ~10× más barato que OpenSearch)
- **Alternativa**: OpenSearch Serverless (más features pero más caro)

## Flujo de una consulta

```
1. Usuario escribe: "¿Cómo se calcula el jacobiano de un brazo 3GDL?"
2. Bedrock genera embedding de la consulta (Titan V2)
3. Vector store busca los 5 chunks más similares (cosine similarity)
4. Bedrock arma prompt: "Contexto: <chunks>. Pregunta: <original>"
5. Claude 3.5 genera respuesta citando páginas
6. Respuesta regresa al usuario
```

Latencia total: ~2-4 segundos por consulta.
