output "cluster_id" {
  value = aws_eks_cluster.pilotgab.id
}

output "node_group_id" {
  value = aws_eks_node_group.pilotgab.id
}

output "vpc_id" {
  value = aws_vpc.pilotgab_vpc.id
}

output "subnet_ids" {
  value = aws_subnet.pilotgab_subnet[*].id
}
