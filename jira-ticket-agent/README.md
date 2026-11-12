# Jira Ticket Agent

Auto-handles simple Jira tickets using AI.

## Setup

1. Install dependencies:
```bash
pip install -r requirements.txt
```

2. Configure environment:
```bash
cp .env.example .env
# Fill in your credentials in .env
```

3. Run the webhook server:
```bash
python webhook_server.py
```

4. Configure Jira webhook:
   - Go to **Jira Settings > System > Webhooks**
   - Create a new webhook pointing to: `http://your-server:5000/jira-webhook`
   - Select event: **Issue Created**

## How it works

1. A new ticket is created in Jira
2. Jira sends a webhook to the agent
3. AI analyzes whether the ticket is simple or complex
4. If **simple**: agent auto-resolves it and adds a comment
5. If **complex**: ticket is left for human handling

## Simple ticket examples
- Password resets
- Access requests
- Status checks
- Documentation questions
