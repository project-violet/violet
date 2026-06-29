$ErrorActionPreference = "Stop"

$body = @{
  model = "exaone3.5:7.8b-awq"
  messages = @(
    @{
      role = "user"
      content = "한국어로 한 문장만 답해줘. OCR 교정 테스트야."
    }
  )
  temperature = 0
  max_tokens = 64
} | ConvertTo-Json -Depth 5

Invoke-WebRequest `
  -Uri http://localhost:8001/v1/chat/completions `
  -Method POST `
  -ContentType "application/json" `
  -Body $body `
  -UseBasicParsing |
  Select-Object -ExpandProperty Content
