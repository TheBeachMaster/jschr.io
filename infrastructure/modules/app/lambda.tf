data "aws_iam_policy_document" "website_generator_trust_policy" {
  # gives permission to AWS to execute the lambda function
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type          = "Service"
      identifiers   = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "website_generator_role" {
  name                = "website_generator_role"
  assume_role_policy  = "${data.aws_iam_policy_document.website_generator_trust_policy.json}"
}

data "aws_iam_policy_document" "website_generator_policy" {
  # gives permission to the lambda function to access the s3 bucket
  statement {
    actions     = ["s3:*"]
    resources   = ["arn:aws:s3:::${var.domain}/*"]
  }

  # gives permission to the lambda function to invalidate the cloudfront distribution
  statement {
    actions     = ["cloudfront:CreateInvalidation"]
    resources   = ["*"]
  }
}

resource "aws_iam_role_policy" "website_generator_policy" {
  name    = "website_generator_policy"
  role    = "${aws_iam_role.website_generator_role.id}"
  policy  = "${data.aws_iam_policy_document.website_generator_policy.json}"
}

resource "aws_lambda_function" "website_generator" {
  filename          = "${var.app_package}"
  function_name     = "website_generator"
  runtime           = "nodejs6.10"
  role              = "${aws_iam_role.website_generator_role.arn}"
  handler           = "handler.default"
  timeout           = 60 # TODO: variable
  memory_size       = 512 # TODO: variable
  source_code_hash  = "${base64sha256(file("${var.app_package}"))}"

  environment {
    variables = {
      NODE_ENV                      = "production"
      S3_BUCKET                     = "${aws_s3_bucket.website.bucket}"
      CF_DISTRIBUTION               = "${aws_cloudfront_distribution.s3_distribution.id}"
      TWITTER_CONSUMER_KEY          = "${var.twitter_consumer_key}"
      TWITTER_CONSUMER_SECRET       = "${var.twitter_consumer_secret}"
      TWITTER_ACCESS_TOKEN          = "${var.twitter_access_token}"
      TWITTER_ACCESS_TOKEN_SECRET   = "${var.twitter_access_token_secret}"
      GA_TRACKING_ID                = "${var.ga_tracking_id}"
      NAME                          = "${var.name}"
      DESCRIPTION                   = "${var.description}"
      EMAIL                         = "${var.email}"
      GITHUB_USERNAME               = "${var.github_username}"
      TWITTER_USERNAME              = "${var.twitter_username}"
      MEDIUM_USERNAME               = "${var.medium_username}"
      LINKEDIN_USERNAME             = "${var.linkedin_username}"
      LINKEDIN_POSITION             = "${var.linkedin_position}"
    }
  }
}

resource "aws_lambda_permission" "allow_generate_website_event" {
    statement_id    = "AllowExecutionFromCloudWatch"
    action          = "lambda:InvokeFunction"
    function_name   = "${aws_lambda_function.website_generator.function_name}"
    principal       = "events.amazonaws.com"
    source_arn      = "${aws_cloudwatch_event_rule.generate_website_event.arn}"
}