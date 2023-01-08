vault {
  renew_token = false
  vault_agent_token_file = "/home/vault/.vault-token"
  retry {
    backoff = "250ms"
    max_backoff = "5m"
  }
}

template {
  destination = "/etc/secrets/index.html"
  contents = <<EOT
<html>
<body>
<p>Some secrets:</p>
{{- with secret "otus/otus-ro/config" }}
<ul>
<li><pre>username: {{ .Data.username }}</pre></li>
<li><pre>password: {{ .Data.password }}</pre></li>
</ul>
{{- end }}
</body>
</html>
EOT
}
