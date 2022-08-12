# -*- coding: utf-8 -*-
# 2021 jiade <wjiad@amazon.com> 
# License AGPL-3.0 or later (https://www.gnu.org/licenses/agpl).

{
    "name": "Redis Session Store",
    "version": "0.2",
    "depends": ["base"],
    "author": "Jiade",
    "license": 'AGPL-3',
    "description": """Use Redis Session instead of File system

    Suggestions & Feedback to: Jiade
    """,
    "summary": "",
    "website": "",
    "category": 'Tools',
    "auto_install": False,
    "installable": True,
    "application": False,
    "external_dependencies": {
        'python': ['redis'],
    },
}
