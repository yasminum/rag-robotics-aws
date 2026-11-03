# Infraestructura como código (IaC)

Esta carpeta contiene los templates de CloudFormation para desplegar toda
la infraestructura del RAG en una sola línea de comandos.

## Archivos

- `knowledge_base.yaml` — CloudFormation template que crea:
  - Bucket S3 `robotic-paper-rag` con carpetas `books/`, `papers/`, `classroom/`
  - IAM role para Bedrock con permisos S3
  - Knowledge Base con Titan Embeddings V2
  - OpenSearch Serverless collection (o S3 Vectors si está disponible)
  - Política de acceso al OpenSearch

## Deploy

```bash
# Crear stack
aws cloudformation create-stack \
    --stack-name rag-robotics \
    --template-body file://knowledge_base.yaml \
    --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
    --region us-east-2

# Esperar a que termine
aws cloudformation wait stack-create-complete \
    --stack-name rag-robotics \
    --region us-east-2

# Ver outputs
aws cloudformation describe-stacks \
    --stack-name rag-robotics \
    --query 'Stacks[0].Outputs' \
    --region us-east-2
```

## Destroy (borrar todo)

```bash
aws cloudformation delete-stack \
    --stack-name rag-robotics \
    --region us-east-2
```

> ⚠️ Borrar el stack NO borra automáticamente el bucket S3 si tiene contenido.
> Para vaciarlo: `aws s3 rm s3://robotic-paper-rag --recursive`
> Y luego: `aws s3api delete-bucket --bucket robotic-paper-rag --region us-east-2`
