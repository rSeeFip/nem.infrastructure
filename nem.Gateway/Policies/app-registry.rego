package nem.app_registry

default allow = false

# Allow access if user has the required role for the app
allow {
  required_role := data.apps[input.app_id].required_role
  required_role == input.user_roles[_]
}

# Allow access if app has no role requirement (public apps)
allow {
  not data.apps[input.app_id].required_role
}
