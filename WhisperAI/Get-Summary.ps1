$ollamaEndpoint = 'http://mp80.localdomain:11434'

$models = (Invoke-RestMethod -Uri "$ollamaEndpoint/api/tags").models

foreach ($model in $models) {
    $model
}

$form = @{
    model  = "llama2"
    prompt = "hi"
}
Invoke-WebRequest -Uri "$ollamaEndpoint/api/generate" -Method 'Post' -Form $form
