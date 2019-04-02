resource "google_container_cluster" "gke-cluster" {
  name               = "iofog-gke-${random_id.instance_id.hex}"
  network            = "default"
  location           = "us-central1-a"
  initial_node_count = 2
}