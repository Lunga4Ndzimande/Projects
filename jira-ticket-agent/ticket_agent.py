import os
import json
from jira import JIRA
from openai import OpenAI
from dotenv import load_dotenv

load_dotenv()

class TicketAgent:
    def __init__(self):
        self.jira = JIRA(
            server=os.getenv('JIRA_URL'),
            basic_auth=(os.getenv('JIRA_EMAIL'), os.getenv('JIRA_API_TOKEN'))
        )
        self.ai = OpenAI(api_key=os.getenv('OPENAI_API_KEY'))

    def analyze_ticket(self, issue_key):
        issue = self.jira.issue(issue_key)

        prompt = f"""Analyze this Jira ticket and determine if it's simple enough to auto-handle.
Title: {issue.fields.summary}
Description: {issue.fields.description}

Simple tickets include: password resets, access requests, status checks, documentation questions.
Respond with JSON: {{"is_simple": true/false, "category": "...", "suggested_action": "..."}}"""

        response = self.ai.chat.completions.create(
            model="gpt-4",
            messages=[{"role": "user", "content": prompt}],
            response_format={"type": "json_object"}
        )

        return json.loads(response.choices[0].message.content)

    def handle_ticket(self, issue_key):
        analysis = self.analyze_ticket(issue_key)

        if not analysis['is_simple']:
            return {"handled": False, "reason": "Complex ticket - needs human review"}

        issue = self.jira.issue(issue_key)
        resolution = self.generate_resolution(issue)

        self.jira.add_comment(issue_key, resolution)
        self.jira.transition_issue(issue_key, 'Done')

        return {"handled": True, "resolution": resolution}

    def generate_resolution(self, issue):
        prompt = f"""Provide a clear resolution for this Jira ticket:
Title: {issue.fields.summary}
Description: {issue.fields.description}

Be concise and actionable."""

        response = self.ai.chat.completions.create(
            model="gpt-4",
            messages=[{"role": "user", "content": prompt}]
        )

        return response.choices[0].message.content
