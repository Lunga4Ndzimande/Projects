from flask import Flask, request, jsonify
from ticket_agent import TicketAgent

app = Flask(__name__)
agent = TicketAgent()

@app.route('/jira-webhook', methods=['POST'])
def handle_webhook():
    data = request.json

    if data.get('webhookEvent') == 'jira:issue_created':
        issue_key = data['issue']['key']
        result = agent.handle_ticket(issue_key)
        return jsonify(result)

    return jsonify({"status": "ignored"})

if __name__ == '__main__':
    app.run(port=5000)
