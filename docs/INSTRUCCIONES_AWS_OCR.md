# OCR gratis en AWS + RAG con Bedrock - Guia completa

## Arquitectura

```
[Tu PC]
   | aws s3 cp libro_escaneado.pdf s3://robotic-paper-rag/raw-scan/
   v
[S3: robotic-paper-rag/raw-scan/]   <- PDFs escaneados entran aqui
   |
   v (pipeline OCR)
[S3: robotic-paper-rag/books/]      <- PDFs con texto salen aqui
   |
   v (Bedrock Knowledge Base Sync)
[OpenSearch Serverless o S3 Vectors] <- vectores indexados
   |
   v
[Bedrock LLM (Claude/Titan)]        <- consultas del usuario
```

## Opcion A: OCR Local en Windows (recomendada para pocos libros)

`powershell
# 1. Setup (instala Tesseract + OCRmyPDF)
.\scripts\02_setup_ocr_windows.ps1

# 2. Procesa y sube tus PDFs
.\scripts\03_pipeline_ocr_windows.ps1 -SourcePath "C:\ruta\escaneados"
`

## Opcion B: OCR en EC2 Free Tier

1. Lanza EC2 Amazon Linux 2023, t3.micro, 30GB disco
2. Asigna IAM role con permisos S3ReadWrite sobre tu bucket
3. Conecta por SSH y ejecuta:
   ``bash
   bash scripts/02_setup_ec2_ocr.sh
   bash scripts/03_pipeline_ocr.sh
   ``

## Costos

| Servicio | Free Tier | Costo pago |
|---|---|---|
| EC2 t3.micro | 750h/mes x 12 meses | $0 |
| S3 5GB | 12 meses | $0.023/GB-mes |
| Bedrock Titan Embeddings | NO | $0.0001/1K tokens |
| Bedrock Claude 3.5 | NO | $3-15 / 1M tokens |
| OpenSearch Serverless | NO | $50-100/mes min |
| S3 Vectors (nuevo 2025) | NO | $0.001/1K vectores |

## Troubleshooting

### OCR falla en PDFs grandes
- t3.micro tiene 1 vCPU, PDFs > 300 paginas tardan 30+ min
- Cambia a t3.small o divide con qpdf --split-pages

### Bedrock no encuentra PDFs
- Verifica que esten en ooks/, papers/ o classroom/, NO en aw-scan/
- El S3 URI en KB debe ser s3://robotic-paper-rag/ (raiz)

### Error "Model access pending"
- Bedrock > Model access > solicita acceso a Titan Embeddings V2
- En cuentas nuevas puede tardar hasta 24h
