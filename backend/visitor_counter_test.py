import functions_framework
from google.cloud import datastore
from google.cloud.datastore import query
import json
from flask import jsonify


@functions_framework.http
def test(request):

    client = datastore.Client()
    kind = 'visitor_counter'
    key = client.key(kind, 'website_visitors')
    
    #Retrieve entity with current visitor count 
    counter_entity = client.get(key)

    #Create initial visitor count if entity does not already exist and set to 0 
    if not counter_entity: 
        counter_entity = datastore.Entity(key=key)
        counter_entity['count'] = 0

    #Update the number of visitors and update the database
    counter_entity['count'] += 1
    client.put(counter_entity)

    total_visitors = {'total_views': str(counter_entity['count'])}

    #Handling CORS 
    if request.method == "OPTIONS":
        # Allows GET requests from any origin with the Content-Type
        # header and caches preflight response for an 3600s
        headers = {
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "GET",
            "Access-Control-Allow-Headers": "Content-Type",
            "Access-Control-Max-Age": "3600",
                    }
        return ("", 204, headers)

    #Set CORS headers for the main request
    headers = {"Access-Control-Allow-Origin": "*"}

    #Return total number of visitors and headers
    return jsonify(total_visitors), 200, headers
