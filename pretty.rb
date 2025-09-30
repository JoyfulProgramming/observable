require "pp"

data = {
  users: [
    {name: "Alice", email: "alice@example.com", roles: ["admin", "user"], active: true, created_at: Time.now},
    {name: "Bob", email: "bob@example.com", roles: ["user"], active: false, created_at: Time.now},
    {name: "Charlie", email: "charlie@example.com", roles: ["moderator", "user"], active: true, created_at: Time.now}
  ],
  settings: {theme: "dark", notifications: true, language: "en"}
}

puts data
