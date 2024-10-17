import boto3
import xml.etree.ElementTree as ET
import os
import json


def lambda_handler(event, context):
    tree = ET.parse('ad_config.xml')
    root = tree.getroot()

    ads = []
    for ad in root.findall('Ad'):
        ad_info = {
            'sequence': ad.get('sequence'),
            'title': ad.find('.//AdTitle').text,
            'duration': ad.find('.//Duration').text,
            'media_url': ad.find('.//MediaFile').text.strip()
        }
        ads.append(ad_info)

    mediatailor = boto3.client('mediatailor')

    configuration_name = os.environ['MEDIATAILOR_CONFIGURATION_NAME']

    try:
        response = mediatailor.get_playback_configuration(
            Name=configuration_name
        )
        update_response = mediatailor.put_playback_configuration(
            Name=configuration_name,
            AdDecisionServerUrl=response['AdDecisionServerUrl'],
            VideoContentSourceUrl=response['VideoContentSourceUrl'],
            AdSegmentUrlPrefix=response['AdSegmentUrlPrefix'],
            Bumper={
                'StartUrl': ads[0]['media_url'],
                'EndUrl': ads[-1]['media_url']
            }
        )

        return {
            'statusCode': 200,
            'body': json.dumps('Ad insertion configuration updated successfully')
        }
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error updating ad insertion configuration: {str(e)}')
        }
