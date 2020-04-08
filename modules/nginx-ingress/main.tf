#
#   ===  Nginx Ingress Controller Deployment  ===
#
#   Ref: https://kubernetes.github.io/ingress-nginx/deploy/
#
resource kubernetes_namespace ingress_nginx {
    metadata {
        name = var.namespace

        labels = {
            "app.kubernetes.io/name"    = var.namespace
            "app.kubernetes.io/part-of" = var.namespace
        }
    }
}
resource kubernetes_config_map nginx_configuration {
    metadata {
        name      = "nginx-configuration"
        namespace = kubernetes_namespace.ingress_nginx.metadata[0].name

        labels = {
            "app.kubernetes.io/name"    = var.namespace
            "app.kubernetes.io/part-of" = var.namespace
        }
    }
}
resource kubernetes_config_map tcp_services {
    metadata {
        name      = "tcp-services"
        namespace = kubernetes_namespace.ingress_nginx.metadata[0].name

        labels = {
            "app.kubernetes.io/name"    = var.namespace
            "app.kubernetes.io/part-of" = var.namespace
        }
    }
}
resource kubernetes_config_map udp_services {
    metadata {
        name      = "udp-services"
        namespace = kubernetes_namespace.ingress_nginx.metadata[0].name

        labels = {
            "app.kubernetes.io/name"    = var.namespace
            "app.kubernetes.io/part-of" = var.namespace
        }
    }
}
resource kubernetes_service_account nginx_ingress_serviceaccount {
    metadata {
        name      = "nginx-ingress-serviceaccount"
        namespace = kubernetes_namespace.ingress_nginx.metadata[0].name

        labels = {
            "app.kubernetes.io/name"    = var.namespace
            "app.kubernetes.io/part-of" = var.namespace
        }
    }
}
resource kubernetes_cluster_role nginx_ingress_clusterrole {
    metadata {
        name    = "nginx-ingress-clusterrole"
        labels  = {
            "app.kubernetes.io/name"    = var.namespace
            "app.kubernetes.io/part-of" = var.namespace
        }
    }
    rule {
        api_groups = [""]
        resources  = ["configmaps", "endpoints", "nodes", "pods", "secrets"]
        verbs      = ["list", "watch"]
    }
    rule {
        api_groups = [""]
        resources  = ["nodes"]
        verbs      = ["get"]
    }
    rule {
        api_groups = [""]
        resources  = ["services"]
        verbs      = ["get", "list", "watch"]
    }
    rule {
        api_groups = [""]
        resources  = ["events"]
        verbs      = ["create", "patch"]
    }
    rule {
        api_groups = ["extensions", "networking.k8s.io"]
        resources  = ["ingresses"]
        verbs      = ["get", "list", "watch"]
    }
    rule {
        api_groups = ["extensions", "networking.k8s.io"]
        resources  = ["ingresses/status"]
        verbs      = ["update"]
    }
}
resource kubernetes_role nginx_ingress_role {
    metadata {
        name        = "nginx-ingress-role"
        namespace   = kubernetes_namespace.ingress_nginx.metadata[0].name
        labels      = {
            "app.kubernetes.io/name"    = var.namespace
            "app.kubernetes.io/part-of" = var.namespace
        }
    }
    rule {
        api_groups = [""]
        resources  = ["configmaps", "pods", "secrets", "namespaces"]
        verbs      = ["get"]
    }
    rule {
        api_groups     = [""]
        resources      = ["configmaps"]
        resource_names = ["ingress-controller-leader-nginx"]
            # Defaults to "<election-id>-<ingress-class>"
            # Here: "<ingress-controller-leader>-<nginx>"
            # This has to be adapted if you change either parameter
            # when launching the nginx-ingress-controller.
        verbs          = ["get", "update"]
    }
    rule {
        api_groups = [""]
        resources  = ["configmaps"]
        verbs      = ["create"]
    }
    rule {
        api_groups = [""]
        resources  = ["endpoints"]
        verbs      = ["get"]
    }
}
resource kubernetes_role_binding nginx_ingress_role_nisa_binding {
    metadata {
        name      = "nginx-ingress-role-nisa-binding"
        namespace = kubernetes_namespace.ingress_nginx.metadata[0].name

        labels = {
            "app.kubernetes.io/name"    = var.namespace
            "app.kubernetes.io/part-of" = var.namespace
        }
    }
    role_ref {
        api_group = "rbac.authorization.k8s.io"
        kind      = "Role"
        name      = "nginx-ingress-role"
    }
    subject {
        kind      = "ServiceAccount"
        name      = kubernetes_service_account.nginx_ingress_serviceaccount.metadata[0].name
        namespace = kubernetes_namespace.ingress_nginx.metadata[0].name
    }
}
resource kubernetes_cluster_role_binding nginx_ingress_clusterrole_nisa_binding {
    metadata {
        name = "nginx-ingress-clusterrole-nisa-binding"

        labels = {
            "app.kubernetes.io/name"    = var.namespace
            "app.kubernetes.io/part-of" = var.namespace
        }
    }
    role_ref {
        api_group = "rbac.authorization.k8s.io"
        kind      = "ClusterRole"
        name      = "nginx-ingress-clusterrole"
    }
    subject {
        kind      = "ServiceAccount"
        name      = kubernetes_service_account.nginx_ingress_serviceaccount.metadata[0].name
        namespace = kubernetes_namespace.ingress_nginx.metadata[0].name
    }
}
resource kubernetes_deployment nginx_ingress_controller {
    metadata {
        name      = "nginx-ingress-controller"
        namespace = kubernetes_namespace.ingress_nginx.metadata[0].name

        labels = {
            "app.kubernetes.io/name"    = var.namespace
            "app.kubernetes.io/part-of" = var.namespace
        }
    }

    spec {
        replicas = 1
        selector {
            match_labels = {
                "app.kubernetes.io/name"    = var.namespace
                "app.kubernetes.io/part-of" = var.namespace
            }
        }
        template {
            metadata {
                labels = {
                    "app.kubernetes.io/name"    = var.namespace
                    "app.kubernetes.io/part-of" = var.namespace
                }
                annotations = {
                    "prometheus.io/port"   = var.probe_port
                    "prometheus.io/scrape" = "true"
                }
            }
            spec {
                # wait up to five minutes for the drain of connections
                termination_grace_period_seconds = 300
                automount_service_account_token = true
                service_account_name = kubernetes_service_account.nginx_ingress_serviceaccount.metadata[0].name
                node_selector = {
                    "kubernetes.io/os" = "linux"
                }
                container {
                    name  = "nginx-ingress-controller"
                    image = "${var.image}:${var.image_version}"
                    args  = [
                        "/nginx-ingress-controller",
                        "--configmap=$(POD_NAMESPACE)/nginx-configuration",
                        "--tcp-services-configmap=$(POD_NAMESPACE)/tcp-services",
                        "--udp-services-configmap=$(POD_NAMESPACE)/udp-services",
                        "--publish-service=$(POD_NAMESPACE)/ingress-nginx",
                        "--annotations-prefix=nginx.ingress.kubernetes.io"
                        ]
                    security_context {
                        allow_privilege_escalation = true
                        capabilities {
                            drop = [ "ALL" ]
                            add = [ "NET_BIND_SERVICE" ]                            
                        }
                        run_as_user = 101
                    }
                    env {
                        name = "POD_NAME"
                        value_from {
                            field_ref {
                                field_path = "metadata.name"
                            }
                        }
                    }
                    env {
                        name = "POD_NAMESPACE"
                        value_from {
                            field_ref {
                                field_path = "metadata.namespace"
                            }
                        }
                    }
                    port {
                        name            = "http"
                        container_port  = 80
                        protocol        = "TCP"
                    }
                    port {
                        name           = "https"
                        container_port = 443
                        protocol        = "TCP"
                    }
                    liveness_probe {
                        failure_threshold     = 3
                        http_get {
                            path   = "/healthz"
                            port   = var.probe_port
                            scheme = "HTTP"
                        }
                        initial_delay_seconds = 10
                        period_seconds        = 10                        
                        success_threshold     = 1
                        timeout_seconds       = 10
                    }
                    readiness_probe {
                        failure_threshold = 3
                        http_get {
                            path   = "/healthz"
                            port   = var.probe_port
                            scheme = "HTTP"
                        }
                        period_seconds    = 10
                        success_threshold = 1
                        timeout_seconds   = 10
                    }
                    lifecycle {
                        pre_stop {
                            exec {
                                command = ["/wait-shutdown"]
                            }
                        }
                    }
                }
            }
        }
    }
}
resource kubernetes_limit_range nginx_ingress_limitrange {
    metadata {
        name = "nginx-ingress"
        namespace = kubernetes_namespace.ingress_nginx.metadata[0].name
        labels = {
            "app.kubernetes.io/name"    = var.namespace
            "app.kubernetes.io/part-of" = var.namespace
        }
    }
    spec {
        limit {
            type = "Container"
            min = {
                cpu = "100m"
                memory = "90Mi"
            }
        }
    }
}
#**/

#   ===  Nginx generic Service to test  ===
#
#   Ref: https://raw.githubusercontent.com/kubernetes/ingress-nginx/nginx-0.30.0/deploy/static/provider/cloud-generic.yaml
#
resource kubernetes_service nginx_test {
    metadata {
        name      = "ingress-nginx"
        namespace = kubernetes_namespace.ingress_nginx.metadata[0].name

        labels = {
            "app.kubernetes.io/name"    = var.namespace
            "app.kubernetes.io/part-of" = var.namespace
        }
    }
    spec {
        type                    = "LoadBalancer"
        external_traffic_policy = "Local"
        selector = {
            "app.kubernetes.io/name"    = var.namespace
            "app.kubernetes.io/part-of" = var.namespace
        }
        port {
            name            = "http"
            port            = 80
            target_port     = "http" #80
            protocol        = "TCP"
        }
        port {
            name            = "https"
            port            = 443
            target_port     = "https" #443
            protocol        = "TCP"
        }
    }
}
#**/