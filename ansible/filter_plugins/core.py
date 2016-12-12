def filter_list(list, key, value):
    return filter(lambda t: t[key] == value, list)

def greater_than(list, key, value):
    return filter(lambda t: t[key] > value, list)


class FilterModule(object):
    def filters(self):
        return {
            'byattr': filter_list,
            'byvaluegreaterthan': greater_than
        }
