# require "bullet/train/ruby/version"
require "open-uri"
require "json"

class BulletTrainClient
  @@apiUrl = ""
  @@environmentKey = ""

  def initialize(apiKey = nil, apiUrl = "https://api.bullet-train.io/api/v1/")
    @@environmentKey = apiKey
    @@apiUrl = apiUrl
  end

  def getJSON(method = nil)
    response = open(@@apiUrl + "" + method.concat("?format=json"),
                    "x-environment-key" => @@environmentKey).read
    return JSON.parse(response)
  end

  def processFlags(inputFlags)
    flags = {}

    for feature in inputFlags
      featureName = feature["feature"]["name"].downcase.gsub(/\s+/, "_")
      enabled = feature["enabled"]
      state = feature["feature_state_value"]
      flags[featureName] = {"enabled" => enabled, "value" => state}

      return flags
    end

    return flags
  end

  def getFlagsForUser(identity = nil)
    processFlags(getJSON("flags/#{identity}"))
  end

  def getFlags()
    processFlags(getJSON("flags"))
  end

  def getValue(key, userId = nil)
    flags = nil
    # Get the features
    if userId != nil
      flags = getFlagsForUser(userId)
    else
      flags = getFlags()
    end
    # Return the value
    return flags[key]["value"]
  end

  def hasFeature(key, userId = nil)
    # Get the features
    flags = nil
    if userId != nil
      flags = getFlagsForUser(userId)
    else
      flags = getFlags()
    end

    # Work out if this feature exists
    if flags[key] == nil
      return false
    else
      return flags[key]["enabled"]
    end
  end
end

# bt = BulletTrain.new("QjgYur4LQTwe5HpvbvhpzK")
# print bt.getFlags()
# print bt.getValue("font_size")
# print bt.hasFeature("font_size")
