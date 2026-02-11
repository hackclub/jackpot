# Jackpot - Las Vegas Hackathon from May 8-12

## Authentication

This app uses Hack Club OAuth for authentication. To set it up:

1. Go to https://auth.hackclub.com/ and create a new OAuth application
2. Copy `.env.example` to `.env` and fill in your credentials:
   ```bash
   cp .env.example .env
   ```
3. Generate a lockbox master key for encrypting access tokens:
   ```bash
   export LOCKBOX_MASTER_KEY=$(openssl rand -hex 32)
   echo "LOCKBOX_MASTER_KEY=$LOCKBOX_MASTER_KEY" >> .env
   ```
4. Restart your Rails server

## User Model

The User model includes:
- `hack_club_id` - Unique identifier from Hack Club
- `display_name` - User's display name
- `email` - User's email address
- `access_token` - Encrypted OAuth access token
- `role` - User role (user or admin)
- `provider` - OAuth provider (hackclub)
- `last_sign_in_at` - Timestamp of last sign in

### Roles

- **user** (0) - Regular user
- **admin** (1) - Administrator with elevated privileges

### Helper Methods

- `current_user` - Returns the currently signed in user
- `user_signed_in?` - Returns true if a user is signed in
- `authenticate_user!` - Redirects to sign in if not authenticated