package nem.federation.common.rate_limit

default allow := false

default decision := {
  "allow": false,
  "limit": 0,
  "window_seconds": 60
}

decision := {
  "allow": input.rate.current_requests < limit_for_tier,
  "limit": limit_for_tier,
  "window_seconds": 60
}

limit_for_tier := 100 if {
  input.auth.tier == "standard"
}

limit_for_tier := 500 if {
  input.auth.tier == "admin"
}

limit_for_tier := 1000 if {
  input.auth.tier == "service"
}

allow if {
  decision.allow == true
}
