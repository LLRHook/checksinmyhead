#!/usr/bin/env python3
"""Fictional Lisbon preview data using real Billington APIs and Drift storage.

No app/source modifications, third-party dependencies, or production endpoints.
Run once to create API data, then with --db after terminating the simulator app.
Run --finalize after capturing the active tab; it uses the real finalization API.
"""
import argparse
import datetime as dt
import hashlib
import json
import pathlib
import sqlite3
import urllib.request

HERE = pathlib.Path(__file__).resolve().parent
STATE = HERE / 'fictional-seed-state.json'
API = 'http://127.0.0.1:18080'
PEOPLE = ['Maya', 'Leo', 'Nora', 'Oliver']
COLORS = [0xFF328983, 0xFF567B9B, 0xFFC3826C, 0xFF8F80A8]


def request(method, endpoint, body=None, token=None, member=None):
    headers = {'Content-Type': 'application/json'}
    if token:
        headers['Authorization'] = 'Bearer ' + token
    if member:
        headers['X-Member-Token'] = member
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(API + endpoint, data=data, headers=headers, method=method)
    with urllib.request.urlopen(req, timeout=30) as response:
        return json.load(response)


def item(name, price, assignments):
    return dict(name=name, price=price, assignments=assignments)


def make_bill(name, items, tip_percentage=0, days_ago=0):
    assert all(abs(sum(i['assignments'].values()) - 100) < 0.00001 for i in items)
    subtotal = round(sum(i['price'] for i in items), 2)
    tip = round(subtotal * tip_percentage / 100, 2)
    shares = []
    for person in PEOPLE:
        details = [dict(name=i['name'], amount=round(i['price'] * i['assignments'][person] / 100, 2), is_shared=len(i['assignments']) > 1)
                   for i in items if person in i['assignments']]
        amount = round(sum(i['amount'] for i in details), 2)
        person_tip = round(amount * tip_percentage / 100, 2)
        shares.append(dict(person_name=person, items=details, subtotal=amount,
                           tax_share=0, tip_share=person_tip, total=round(amount + person_tip, 2)))
    assert abs(sum(s['total'] for s in shares) - subtotal - tip) < 0.00001
    date = (dt.datetime.now(dt.timezone.utc) - dt.timedelta(days=days_ago)).replace(hour=19, minute=30, second=0, microsecond=0).isoformat()
    return dict(name=name, subtotal=subtotal, tax=0, tip_amount=tip, tip_percentage=tip_percentage,
                total=round(subtotal + tip, 2), currency_code='USD', date=date,
                participants=[dict(name=p) for p in PEOPLE], payment_methods=[],
                person_shares=shares,
                items=[dict(name=i['name'], price=i['price'], assignments=[dict(person_name=p, percentage=v) for p, v in i['assignments'].items()]) for i in items])


def seed_api():
    request('GET', '/health')
    tab = request('POST', '/api/tabs', dict(name='Lisbon weekend', description='Good food. Great company.', creator_display_name='Maya'))
    members = [dict(display_name='Maya', member_token=tab['member_token'])]
    for name in PEOPLE[1:]:
        member = request('POST', f"/api/tabs/{tab['tab_id']}/join", dict(display_name=name), tab['access_token'])
        members.append(member)
    shared = {p: 25 for p in PEOPLE}
    bills = [
        make_bill('Dinner in Alfama', [item('Grilled sea bass', 32, {'Leo': 100}),
                  item('Mushroom rice', 24, {'Maya': 100}), item('Roasted octopus', 28, {'Nora': 100}),
                  item('Tomato salad', 14, {'Oliver': 100}), item('Marinated olives', 8, shared),
                  item('Sparkling water', 12, shared)], 10, 0),
        make_bill('Tram & viewpoints', [item('Tram day passes', 28, shared)], 0, 1),
        make_bill('Pastéis & coffee', [item('Pastéis de nata', 12, shared), item('Flat whites', 10, {'Maya':50, 'Nora':50}),
                  item('Iced lattes', 12, {'Leo':50, 'Oliver':50})], 0, 2),
    ]
    for bill in bills:
        remote = request('POST', '/api/bills', bill)
        request('POST', f"/api/tabs/{tab['tab_id']}/bills", dict(bill_id=remote['bill_id'], bill_token=remote['access_token']), tab['access_token'], tab['member_token'])
        bill['remote'] = remote
    state = dict(tab=tab, members=members, bills=bills, finalized=False)
    STATE.write_text(json.dumps(state, indent=2) + '\n')
    return state


def seed_db(db_path, state):
    if not db_path.is_file():
        raise SystemExit('Launch app once to initialize Drift, terminate it, then provide existing split_bill.sqlite.')
    conn = sqlite3.connect(db_path)
    if conn.execute('pragma user_version').fetchone()[0] != 8:
        raise SystemExit('Expected real app Drift schema version 8.')
    if conn.execute('select count(*) from recent_bills').fetchone()[0] > 0:
        if not conn.execute("select 1 from tabs where name='Lisbon weekend'").fetchone():
            raise SystemExit('Refusing to alter a populated non-preview simulator DB.')
    backup_id = hashlib.sha256(str(db_path).encode()).hexdigest()[:8]
    backup_path = HERE / f'simulator-db-before-seed-{backup_id}.sqlite'
    if not backup_path.exists():
        with sqlite3.connect(backup_path) as backup:
            conn.backup(backup)
    now = int(dt.datetime.now(dt.timezone.utc).timestamp())
    with conn:
        if not conn.execute('select 1 from user_preferences').fetchone():
            conn.execute('insert into user_preferences(show_all_items,show_person_items,show_breakdown,updated_at) values(1,1,1,?)', (now,))
        for index, name in enumerate(PEOPLE):
            found = conn.execute('select id from people where name=?', (name.lower(),)).fetchone()
            if not found:
                conn.execute('insert into people (name,color_value,last_used,use_count) values (?,?,?,?)', (name.lower(), COLORS[index], now, 5))
        if not conn.execute("select 1 from people_groups where name='Lisbon crew'").fetchone():
            group = conn.execute('insert into people_groups(name,color_value,is_suggested,created_at,last_used) values(?,?,0,?,?)', ('Lisbon crew', COLORS[0], now, now)).lastrowid
            for name in PEOPLE:
                person_id = conn.execute('select id from people where name=?', (name.lower(),)).fetchone()[0]
                conn.execute('insert into people_group_members(group_id,person_id) values(?,?)', (group,person_id))
        local_ids = []
        for index, bill in enumerate(state['bills']):
            remote = bill['remote']
            existing = conn.execute('select id from recent_bills where share_url=?', (remote['share_url'],)).fetchone()
            if existing:
                local_ids.append(existing[0]); continue
            items = [dict(name=i['name'], price=i['price'], assignments={a['person_name']:a['percentage'] for a in i['assignments']}) for i in bill['items']]
            columns = ['bill_name','participants','participant_count','total','date','subtotal','tax','tip_amount','tip_percentage','items','color_value','created_at','share_url','currency_code','usd_exchange_rate','exchange_rate_date','exchange_rate_source']
            values = [bill['name'],json.dumps(PEOPLE),len(PEOPLE),bill['total'],bill['date'],bill['subtotal'],0,bill['tip_amount'],bill['tip_percentage'],json.dumps(items),COLORS[0],now-index*86400,remote['share_url'],remote['currency_code'],remote['usd_exchange_rate'],remote['exchange_rate_date'],remote['exchange_rate_source']]
            local_ids.append(conn.execute('insert into recent_bills('+','.join(columns)+') values('+','.join('?' for _ in columns)+')',values).lastrowid)
        tab = state['tab']
        existing_tab = conn.execute('select id from tabs where backend_id=?', (tab['tab_id'],)).fetchone()
        if existing_tab:
            conn.execute('update tabs set finalized=? where id=?', (int(state['finalized']),existing_tab[0]))
        else:
            conn.execute('insert into tabs(name,description,bill_ids,backend_id,access_token,share_url,finalized,member_token,role,is_remote,created_at) values(?,?,?,?,?,?,?,?,?,0,?)',
                         ('Lisbon weekend','Good food. Great company.',','.join(map(str,local_ids)),tab['tab_id'],tab['access_token'],tab['share_url'],int(state['finalized']),tab['member_token'],'creator',now))
        conn.execute('insert or ignore into tutorial_states(tutorial_key,has_been_seen,last_shown_date) values(?,1,?)', ('has_seen_item_assignment_tutorial',now))
    conn.close()
    print('Seeded real simulator DB:', db_path)


def finalize(state):
    tab = state['tab']
    if not state['finalized']:
        settlements = request('POST', f"/api/tabs/{tab['tab_id']}/finalize", {}, tab['access_token'],tab['member_token'])
        state['finalized'] = True
        state['settlements'] = settlements
        for settlement in settlements:
            if settlement['person_name'] in ('Maya','Nora'):
                request('PATCH', f"/api/tabs/{tab['tab_id']}/settlements/{settlement['id']}",dict(paid=True),tab['access_token'],tab['member_token'])
        STATE.write_text(json.dumps(state, indent=2)+'\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--db', type=pathlib.Path)
    parser.add_argument('--finalize', action='store_true')
    args = parser.parse_args()
    state = json.loads(STATE.read_text()) if STATE.exists() else seed_api()
    remote_tab = request('GET', f"/api/tabs/{state['tab']['tab_id']}", token=state['tab']['access_token'])
    state['finalized'] = remote_tab['finalized']
    STATE.write_text(json.dumps(state, indent=2) + '\n')
    if args.finalize:
        finalize(state)
    if args.db:
        seed_db(args.db,state)
    print('Fictional preview state ready:', STATE)
    print(state['bills'][0]['currency_code'], 'total:', sum(b['total'] for b in state['bills']))
    print('API quote:', {k:state['bills'][0]['remote'][k] for k in ('usd_exchange_rate','exchange_rate_date','exchange_rate_source')})


if __name__ == '__main__':
    main()
