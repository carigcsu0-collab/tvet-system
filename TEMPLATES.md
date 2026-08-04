# Adding Your Templates

The system uses `PhpOffice/PhpWord TemplateProcessor` to merge `.docx` Word templates with form data. No PDF conversion is needed for the MVP; it generates `.docx` files.

## Placeholder Tags

Use these placeholders inside your `.docx` files. Add a matching tag for each field you fill in the Flutter form.

### Certificate of Appearance
- `${name}`
- `${purpose}`
- `${office}`
- `${coordinatorName}`
- `${code}`
- `${date}`
- `${year}`

### Internal Communication
- `${to}`
- `${from}`
- `${subject}`
- `${body}`
- `${coordinatorName}`
- `${code}`
- `${date}`
- `${year}`

### External Communication
- `${recipient}`
- `${organization}`
- `${address}`
- `${subject}`
- `${body}`
- `${coordinatorName}`
- `${code}`
- `${date}`
- `${year}`

## Upload a Template

1. Start the backend and log in.
2. Get the document type `id` from `GET /api/v1/document-types`.
3. Upload the `.docx` with cURL:

```bash
curl -X POST http://localhost:3001/api/v1/templates \
  -H "Authorization: Bearer <TOKEN>" \
  -F "documentTypeId=<TYPE_ID>" \
  -F "file=@/path/to/template.docx"
```

The uploaded template becomes the active template for that document type. Generating a document will fail until a template is active.

## Next Steps for Scaling

- Convert templates to PDF with LibreOffice or an API.
- Move storage from local disk to S3-compatible object storage.
- Add per-office coordinator overrides and more document types through the `DocumentType` table.
