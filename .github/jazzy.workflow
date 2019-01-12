workflow "Jazzy" {
  on = "push"
  resolves = ["Run Jazzy"]
}

action "Run Jazzy" {
  uses = "docker://norionomura/jazzy:0.9.4_swift-4.2.1"
  secrets = ["GITHUB_TOKEN"]
  runs = "jazzy"
}
