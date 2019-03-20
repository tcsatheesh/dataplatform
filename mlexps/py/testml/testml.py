import argparse
from azureml.core import Workspace
from azureml.core import Experiment

def createExperiement(ws, experimentName):
    # Create a new experiment in your workspace.
    exp = Experiment(workspace=ws, name=experimentName)
    # Start a run and start the logging service.
    run = exp.start_logging()
    # Log a single  number.
    run.log('my magic number', 42)
    # Log a list (Fibonacci numbers).
    run.log_list('my list', [1, 1, 2, 3, 5, 8, 13, 21, 34, 55]) 
    # Finish the run.
    run.complete()
    print("Run url: {0}".format(run.get_portal_url()))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('-c', '--config')
    parser.add_argument('-n', '--name', default='exp01')
    parser.add_argument('-v', '--verbose', dest='verbose', action='store_true')
    parser.add_argument('--version', action='version', version='%(prog)s 1.0')
    args = parser.parse_args()
    if (args.verbose):
        print ("Config file: {0}".format(args.config))
        print ("Name value: {0}".format(args.name))
        print ("Verbose value: {0}".format(args.verbose))
    ws = Workspace.from_config(path=args.config)
    createExperiement(ws, args.name)