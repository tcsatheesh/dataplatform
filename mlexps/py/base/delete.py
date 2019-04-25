import os
import utils
import pickle
import argparse

from azureml.core import Workspace
from azureml.core.webservice import Webservice
 

def deleteWebService(ws,args):
    services = Webservice.list(workspace=ws, model_name=args.modelName)
    if (len(services) == 0):
        print ("Webservice is not deployed.")        
    else:
        print ("Webservice is deployed")
        services[0].delete()
        print ("Deleted webservice")


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--modelName', required=True)
    parser.add_argument('--webserviceName', required=True)
    parser.add_argument('--config', default='config.json')
    parser.add_argument('--spconfig', default='spconfig.json')
    parser.add_argument('--aml_config_dir', default='aml_config')
    parser.add_argument('-v', '--verbose', dest='verbose', action='store_true')
    parser.add_argument('--version', action='version', version='%(prog)s 1.0')
    args = parser.parse_args()
    if (args.verbose):
        print ("config file: {0}".format(args.config))
        print ("verbose value: {0}".format(args.verbose))
    
    utils.setConfigFiles(args)
    svc_pr = utils.loadAuthCredentials(args)
    ws = Workspace.from_config(path=args.config, auth=svc_pr)
    deleteWebService(ws,args)
    