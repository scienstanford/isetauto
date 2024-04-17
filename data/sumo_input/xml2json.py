import xml.etree.ElementTree as ET
import json
import optparse
def get_options(args=None):
    # add options for matlab calls
    optParser = optparse.OptionParser()
    # for example "city_cross_4lanes";
    optParser.add_option("-f", "--xml-file", dest="stateFile",
                         help="define the name of state xml file")
    optParser.add_option("-t", "--tl-xml-file", dest="tlFile",
                         help="define the name of tl state xml file")
    optParser.add_option("-o", "--output-json-file", dest="jsonFile",
                         default="json", help="define json file name")
                         
    (options, args) = optParser.parse_args(args=args)
    return options

def state2dict(stateFile):
    tree = ET.ElementTree(file=stateFile)
    root = tree.getroot()
    statesDict={}
    for step in root:
        print(step.tag)
        print(step.attrib)
        key_step = str(float(step.attrib['time']))
        statesDict[key_step] = {}
        vList=[]

        for vehicle in step:
            v_class = vehicle.tag           
            if v_class == 'person':
                v_class = 'pedestrain' # as is named in isetauto
                v_type = v_class
            else:
                v_type = vehicle.attrib['type']                          
                
            if 'z' in vehicle.attrib:
                v_pos = [vehicle.attrib['x'],vehicle.attrib['y'],vehicle.attrib['z']]
            else:
                v_pos = [vehicle.attrib['x'],vehicle.attrib['y']]
            vDict = {}
            vDict['class'] = v_type
            vDict['name'] = vehicle.attrib['id']
            vDict['type'] = [] # What's this?
            vDict['pos'] = v_pos
            vDict['speed'] = vehicle.attrib['speed']
            vDict['orientation'] = vehicle.attrib['slope']
            vList.append(vDict)
            
            
        statesDict[key_step] = vList
    return(statesDict) 

def tl2dict(tlFile):
    tree = ET.ElementTree(file=tlFile)
    root = tree.getroot()
    statesDict={}
    for step in root:
        print(step.tag)
        print(step.attrib)
        key_step = str(float(step.attrib['time']))
        
        if key_step not in statesDict:
            statesDict[key_step] = []
        tlDict = {}
        tlDict['name'] = step.attrib['id']
        tlDict['state'] = step.attrib['state']
        statesDict[key_step].append(tlDict)
        
    return statesDict


def combine(options):
    vDict = state2dict(options.stateFile) # vehicle & person
    tlDict = tl2dict(options.tlFile) # traffic light
    outputDict = {}
    i = 0
    for vTime in vDict.keys():
        tfState = {}
        tfState['Objects']  = vDict[vTime]
        tfState["TrafficLights"] = tlDict[vTime]
        tfState['timestamp'] = vTime

        outputDict[str(i)] = tfState

        i=i+1
    with open(options.jsonFile, 'w') as outfile:
        json.dump(outputDict, outfile)

def main(options):
    tldict = combine(options)
if __name__ == "__main__":
    main(get_options())    