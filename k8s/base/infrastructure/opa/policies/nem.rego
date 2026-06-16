package nem.authz

default allow = false

allow {
  input.subject == "platform-bootstrap"
}

allow {
  some i
  input.roles[i] == "admin"
  input.action == "delete"
}

allow {
  input.action != "delete"
  count(input.roles) > 0
}
