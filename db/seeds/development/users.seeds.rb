# frozen_string_literal: true

User
  .create_with(name: 'Admin', password: 'password').find_or_create_by!(email: 'admin@example.org', role: 1)
