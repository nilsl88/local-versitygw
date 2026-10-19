# Prep
mkdir -p ./data ./meta/sidecar ./iam ./certs

# Start it
podman compose -f docker-compose.yaml up -d

# Create one admin account + 3 user accounts (each with keys)
export ADMIN_ENDPOINT_URL="http://host.containers.internal:7071"
export ROOT_ACCESS_KEY_ID="rootaccess"
export ROOT_SECRET_ACCESS_KEY="rootsecret"

# Create an admin account (recommended for bucket provisioning)
podman exec -it versitygw versitygw admin --access "$ROOT_ACCESS_KEY_ID" --secret "$ROOT_SECRET_ACCESS_KEY" --endpoint-url "$ADMIN_ENDPOINT_URL" create-user --access vadmin --secret vadminsecret --role admin

# Create 3 users
podman exec -it versitygw versitygw admin --access "$ROOT_ACCESS_KEY_ID" --secret "$ROOT_SECRET_ACCESS_KEY" --endpoint-url "$ADMIN_ENDPOINT_URL" create-user --access user1 --secret user1secret --role user

podman exec -it versitygw versitygw admin --access "$ROOT_ACCESS_KEY_ID" --secret "$ROOT_SECRET_ACCESS_KEY" --endpoint-url "$ADMIN_ENDPOINT_URL" create-user --access user2 --secret user2secret --role user

podman exec -it versitygw versitygw admin --access "$ROOT_ACCESS_KEY_ID" --secret "$ROOT_SECRET_ACCESS_KEY" --endpoint-url "$ADMIN_ENDPOINT_URL" create-user --access user3 --secret user3secret --role user

# List users
podman exec -it versitygw versitygw admin --access "$ROOT_ACCESS_KEY_ID" --secret "$ROOT_SECRET_ACCESS_KEY" --endpoint-url "$ADMIN_ENDPOINT_URL" list-users

# Create a bucket for each user (admin creates, then assigns ownership)

# Create the buckets using AWS CLI as the admin
podman run --rm \
  --entrypoint /bin/sh \
  -e AWS_ACCESS_KEY_ID="vadmin" \
  -e AWS_SECRET_ACCESS_KEY="vadminsecret" \
  -e AWS_ENDPOINT_URL="http://host.containers.internal:7070" \
  -e AWS_DEFAULT_REGION="us-east-1" \
  amazon/aws-cli \
  -lc '
    aws s3 --endpoint-url "$AWS_ENDPOINT_URL" mb s3://user1-bucket
    aws s3 --endpoint-url "$AWS_ENDPOINT_URL" mb s3://user2-bucket
    aws s3 --endpoint-url "$AWS_ENDPOINT_URL" mb s3://user3-bucket
  '

# Change bucket owner to each user
podman exec -it versitygw versitygw admin --access "$ROOT_ACCESS_KEY_ID" --secret "$ROOT_SECRET_ACCESS_KEY" --endpoint-url "$ADMIN_ENDPOINT_URL" change-bucket-owner --bucket user1-bucket --owner user1

podman exec -it versitygw versitygw admin --access "$ROOT_ACCESS_KEY_ID" --secret "$ROOT_SECRET_ACCESS_KEY" --endpoint-url "$ADMIN_ENDPOINT_URL" change-bucket-owner --bucket user2-bucket --owner user2

podman exec -it versitygw versitygw admin --access "$ROOT_ACCESS_KEY_ID" --secret "$ROOT_SECRET_ACCESS_KEY" --endpoint-url "$ADMIN_ENDPOINT_URL" change-bucket-owner --bucket user3-bucket --owner user3

# Validate each user sees only their bucket
podman run --rm \
  --entrypoint /bin/sh \
  -e AWS_ENDPOINT_URL="http://host.containers.internal:7070" \
  -e AWS_DEFAULT_REGION="us-east-1" \
  amazon/aws-cli \
  -lc '
    AWS_ACCESS_KEY_ID=user1 AWS_SECRET_ACCESS_KEY=user1secret aws --endpoint-url "$AWS_ENDPOINT_URL" s3 ls
    AWS_ACCESS_KEY_ID=user2 AWS_SECRET_ACCESS_KEY=user2secret aws --endpoint-url "$AWS_ENDPOINT_URL" s3 ls
    AWS_ACCESS_KEY_ID=user3 AWS_SECRET_ACCESS_KEY=user3secret aws --endpoint-url "$AWS_ENDPOINT_URL" s3 ls
  '

# List Buckets and Owners
podman exec -it versitygw versitygw admin --access "$ROOT_ACCESS_KEY_ID" --secret "$ROOT_SECRET_ACCESS_KEY" --endpoint-url "$ADMIN_ENDPOINT_URL" list-buckets
