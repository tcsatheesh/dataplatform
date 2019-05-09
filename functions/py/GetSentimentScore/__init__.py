import logging

import azure.functions as func

import json
from textblob import TextBlob

def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')

    req_body = req.get_json()
    tweet = req_body.get('tweet')

    logging.info('tweet was {}'.format(tweet))

    tweet_sentiment = TextBlob(tweet)
    data = {}
    data['polarity'] = tweet_sentiment.sentiment.polarity
    data['subjectivity'] = tweet_sentiment.sentiment.subjectivity
    json_data = json.dumps(data)

    if tweet:
        return func.HttpResponse(json_data)
    else:
        return func.HttpResponse(
             "Please pass a tweet in the request body",
             status_code=400
        )
