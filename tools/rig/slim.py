"""Shared clean-up before exporting a model for the game (imported by the other
rig scripts). The game's cel shader only reads the colour texture, so normal,
roughness and metal maps are dropped (they tripled the download), and textures
are capped at `max_size`."""
import bpy


def slim_textures(max_size=2048, keep_maps=False):
    if keep_maps:
        for img in bpy.data.images:
            if img.size[0] > max_size:
                img.scale(max_size, int(max_size * img.size[1] / img.size[0]))
        return
    for mat in bpy.data.materials:
        if not mat.use_nodes:
            continue
        nt = mat.node_tree
        keep = set()
        for node in nt.nodes:
            if node.type == "BSDF_PRINCIPLED":
                for link in list(nt.links):
                    if link.to_node == node and link.to_socket.name != "Base Color":
                        nt.links.remove(link)
                for link in nt.links:
                    if link.to_node == node and link.to_socket.name == "Base Color" and link.from_node.type == "TEX_IMAGE":
                        keep.add(link.from_node)
        for node in list(nt.nodes):
            if node.type == "TEX_IMAGE" and node not in keep:
                nt.nodes.remove(node)
            elif node.type in ("NORMAL_MAP", "SEPARATE_COLOR", "SEPRGB"):
                nt.nodes.remove(node)
    for img in list(bpy.data.images):
        if img.users == 0:
            bpy.data.images.remove(img)
        elif img.size[0] > max_size:
            img.scale(max_size, int(max_size * img.size[1] / img.size[0]))
