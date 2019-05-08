local defaultStyle = data.raw["gui-style"]["default"]

defaultStyle.muppet_padded_horizontal_flow = {
    type = "horizontal_flow_style",
    left_padding = 4,
    top_padding = 4
}
defaultStyle.muppet_padded_vertical_flow = {
    type = "vertical_flow_style",
    left_padding = 4,
    top_padding = 4
}

defaultStyle.muppet_padded_frame = {
    type = "frame_style",
    left_padding = 4,
    top_padding = 4
}
defaultStyle.muppet_margin_frame = {
    type = "frame_style",
    left_margin = 4,
    top_margin = 4
}

defaultStyle.muppet_padded_table = {
    type = "table_style",
    top_padding = 5,
    bottom_padding = 5,
    left_padding = 5,
    right_padding = 5
}
defaultStyle.muppet_padded_table_cell = {
    type = "label_style",
    top_padding = 5,
    bottom_padding = 5,
    left_padding = 5,
    right_padding = 5
}

defaultStyle.muppet_mod_button_sprite = {
    type = "button_style",
    width = 36,
    height = 36,
    scalable = true
}
--same size as a button
defaultStyle.muppet_button_sprite = {
    type = "button_style",
    width = 42,
    height = 42,
    scalable = true
}
defaultStyle.muppet_small_button = {
    type = "button_style",
    padding = 2,
    font = "default"
}

defaultStyle.muppet_text = {
    type = "label_style",
    font = "default"
}
defaultStyle.muppet_semibold_text = {
    type = "label_style",
    font = "default-semibold"
}
defaultStyle.muppet_bold_text = {
    type = "label_style",
    font = "default-bold"
}

defaultStyle.muppet_large_text = {
    type = "label_style",
    font = "default-large"
}
defaultStyle.muppet_large_semibold_text = {
    type = "label_style",
    font = "default-large-semibold"
}
defaultStyle.muppet_large_bold_text = {
    type = "label_style",
    font = "default-large-bold"
}
