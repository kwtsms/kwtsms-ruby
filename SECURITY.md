# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| 0.4.x   | Yes       |
| 0.3.x   | No        |
| 0.2.x   | No        |
| 0.1.x   | No        |

## Reporting a Vulnerability

If you discover a security vulnerability, please report it responsibly.

**Do NOT open a public GitHub issue for security vulnerabilities.**

Instead, email: **info@boxlink.net**

Include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

You will receive a response within 48 hours. We will work with you to understand and address the issue before any public disclosure.

## Security Best Practices

When using this library:

- Never hardcode API credentials in source code
- Use environment variables or `.env` files for credentials
- Add `.env` to `.gitignore`
- Use `test_mode: true` during development
- Implement rate limiting in your application
- Use CAPTCHA/bot protection on forms that trigger SMS
- Register a private Sender ID before going live
- Use Transactional Sender ID for OTP messages
