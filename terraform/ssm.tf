resource "aws_ssm_parameter" "telegram-bot-token" {
  name  = "telegram-bot-token"
  description = "Token for Telegram bot"
  type  = "SecureString"
  value = var.telegram_token
}