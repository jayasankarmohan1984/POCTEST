variable "rgs" {
  type = map(object({
    name     = string
    location = string
  }))
}

variable "tags" {
  type = map(string)
}