def filter_list(list, key, value):
    return filter(lambda t: t[key] == value, list)

def greater_than(list, key, value):
    return filter(lambda t: t[key] > value, list)

def flatten(list_of_lists):
    return filter(lambda l: [item for sublist in l for item in sublist], list_of_lists)

class FilterModule(object):
    def filters(self):
        return {
            'byattr': filter_list,
            'byvaluegreaterthan': greater_than
        }
