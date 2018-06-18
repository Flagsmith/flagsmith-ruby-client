require "bullet-train"

bt = BulletTrain.new("QjgYur4LQTwe5HpvbvhpzK")

if bt.getValue("font_size")
  #    Do something awesome with the font size
  puts bt.getValue("font_size")
end

if bt.hasFeature("does_not_exist")
  #do something
else
  #do nothing, or something else
end
