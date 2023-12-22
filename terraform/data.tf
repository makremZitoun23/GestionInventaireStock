data "template_file" "cloud-init" {
    template = file("${path.module}/custom_data.tpl")
}