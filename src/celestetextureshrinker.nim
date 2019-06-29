
import streams
from stb_image/read as stbi import load
from stb_image/write as stbiw import writePNG
import os
from strutils import replace
from osproc import startProcess

let newTextureSize = 2048

proc read7BitEncodedInt(stream: Stream): int32 =
  var count:uint32
  var shift = 0
  while true:
    if shift == 5 * 7:
      raise newException(Exception, "Bad7BitInt32: " & $count)
    let b = stream.readUint8()
    count = count or (uint32(b and 0x7F) shl shift)
    inc shift, 7
    if (b and 0x80) == 0:
      break
  return cast[int32](count)

proc readString(stream: Stream): TaintedString =
  return stream.readStr(stream.read7BitEncodedInt())

proc write7BitEncodedInt(stream: Stream, number: int) =
  var v = cast[uint32](int32 number)
  while v >= uint32 0x80:
    stream.write(cast[byte](v or 0x80))
    v = v shr 7
  stream.write(byte v)

proc writeString(stream: Stream, str: string) =
  stream.write7BitEncodedInt(str.len)
  stream.write(str)

proc extract(filename: string, outdir: string) =
  echo "Extracting sprites from ", filename, " to ", outdir
  let (dir, baseName, ext) = os.splitFile(filename)
  
  let metafile = newFileStream(filename, fmRead)
  defer: metafile.close()
  let header_version = metafile.readInt32()
  let header_args = metafile.readString()
  let header_hash = metafile.readInt32()

  echo "args: ", header_args

  let textures = metafile.readInt16()
  echo "number of textures: ", textures

  for i in 0..<textures:
    var textureName = metafile.readString()
    echo "  texture: ", textureName
    let texstream = newFileStream(os.joinPath(dir, textureName & ".data"))
    defer: texstream.close()

    let texw = texstream.readInt32()
    let texh = texstream.readInt32()
    let isTransparent = texstream.readBool()

    echo "  size: ", texw, "x", texh
    echo "  transparent: ", isTransparent

    let channels = if isTransparent: 4 else: 3
    let format = if isTransparent: stbiw.RGBA else: stbiw.RGB

    var atlas = newSeq[byte](uint32(texw) * uint32(texh) * uint32(channels))
    var pos = 0
    while pos < atlas.len:
      let runLength = texstream.readUint8()
      let a = if isTransparent: texstream.readUint8() else: 255
      var r, g, b:byte
      if a != 0:
        b = texstream.readUint8()
        g = texstream.readUint8()
        r = texstream.readUint8()

      for i in 0..<int runLength:
        atlas[pos + 0] = r
        atlas[pos + 1] = g
        atlas[pos + 2] = b
        atlas[pos + 3] = a
        inc pos, 4

    texstream.close()

    # writePNG("output/atlas_" & textureName & ".png", texw, texh, format, atlas)

    let subtextures = metafile.readInt16()
    echo "  subtextures: ", subtextures
    for j in 0..<subtextures:

      let name = metafile.readString()
      let x = metafile.readInt16()
      let y = metafile.readInt16()
      let w = metafile.readInt16()
      let h = metafile.readInt16()
      let fx = metafile.readInt16()
      let fy = metafile.readInt16()
      let fw = metafile.readInt16()
      let fh = metafile.readInt16()

      echo "    name: ", name
      # echo "      (", x, "x", y, ", ", w, "x", h, ")"
      # echo "      (", fx, "x", fy, ", ", fw, "x", fh, ")"

      var pixels = newSeq[byte](uint32(fw) * uint32(fh) * uint32(channels))

      pos = ((y + int(w - 1)) * texw + x + int(h / 2)) * channels

      # echo atlas[pos..pos+3]

      for yi in 0..<h:
        for xi in 0..<w:
          let posfrom = ((y + yi) * texw + x + xi) * channels
          let posto = ((yi - fy) * fw + xi - fx) * channels
          pixels[posto + 0] = atlas[posfrom + 0] # r
          pixels[posto + 1] = atlas[posfrom + 1] # g
          pixels[posto + 2] = atlas[posfrom + 2] # b
          if isTransparent:
            pixels[posto + 3] = atlas[posfrom + 3]

          # pixels[pos+3] = 255
          # echo xi, "x", yi, "  ", pixels[pos..pos+3]
      let namepath = os.joinPath(outdir, strutils.replace(os.normalizedPath(name), "\\", "/") & ".png")
      let spritedir = os.splitFile(namepath).dir
      os.createDir spritedir
      writePNG(namepath, fw, fh, format, pixels)

# Tests .data file
proc testData(filename: string) =
  echo "Testing .data file:", filename

  let texstream = newFileStream(filename)
  defer: texstream.close()

  let texw = texstream.readInt32()
  let texh = texstream.readInt32()
  let isTransparent = texstream.readBool()

  echo "  size: ", texw, "x", texh
  echo "  transparent: ", isTransparent

  let channels = if isTransparent: 4 else: 3
  let format = if isTransparent: stbiw.RGBA else: stbiw.RGB

  var atlas = newSeq[byte](uint32(texw) * uint32(texh) * uint32(channels))
  var pos = 0
  while pos < atlas.len:
    let runLength = texstream.readUint8()
    # echo "  runLength: ", runLength
    let a = if isTransparent: texstream.readUint8() else: 255
    var r, g, b:byte
    if a != 0:
      b = texstream.readUint8()
      g = texstream.readUint8()
      r = texstream.readUint8()

    # echo "  pixel ", [r, g, b, a], "  pos: ", pos, " / ", atlas.len

    for i in 0..<int runLength:
      # if pos >= atlas.len: break # temporary fix
      atlas[pos + 0] = r
      atlas[pos + 1] = g
      atlas[pos + 2] = b
      atlas[pos + 3] = a
      inc pos, 4

  texstream.close()

  writePNG("atlas_test.png", texw, texh, format, atlas)

proc convertPngToData(filename: string) =
  echo "Converting .png to .data ", filename
  let (dir, baseName, ext) = os.splitFile(filename)

  var
    texw, texh, channels:int
    pixels:seq[byte]

  pixels = stbi.load(filename, texw, texh, channels, stbi.Default)

  let xnbstream = newFileStream(os.joinPath(dir, baseName & ".data"), fmWrite)
  defer: xnbstream.close()

  echo "  size: ", texw, "x", texh
  echo "  channels: ", channels

  xnbstream.write(int32 texw)
  xnbstream.write(int32 texh)
  xnbstream.write(true)

  var rc, gc, bc, ac:byte
  var runLength:byte = 0

  var sanity = 0
  var pos = 0

  for i in 0..<texw * texh:
    var r, g, b, a:uint8
    if channels == stbi.RGBA or channels == stbi.RGB:
      r = pixels[i * channels + 0]
      g = pixels[i * channels + 1]
      b = pixels[i * channels + 2]
      if channels != stbi.RGB:
        a = pixels[i * channels + 3]
      else:
        a = uint8.high
    elif channels == stbi.GreyAlpha:
      r = pixels[i * channels + 0]
      g = pixels[i * channels + 0]
      b = pixels[i * channels + 0]
      a = pixels[i * channels + 1]
    else:
      raise newException(Exception, "Unsupported color channel: " & $channels)

    if i == 0:
      rc = r
      gc = g
      bc = b
      ac = a
      # echo "clear cache INIT!"

    # echo "pixel ", i, " ", [r, g, b, a], " ", runLength

    if rc == r and gc == g and bc == b and ac == a and runLength != runLength.high:
      inc runLength
      if i < texw * texh - 1:
        continue

    # echo "WRITING ", [rc, gc, bc, ac], " count: ", runLength
    xnbstream.write(runLength)
    xnbstream.write(ac)
    if ac > byte 0:
      xnbstream.write(bc)
      xnbstream.write(gc)
      xnbstream.write(rc)
    inc sanity, int runLength
    runLength = 1

    rc = r
    gc = g
    bc = b
    ac = a
    # echo "clearing cache!"

  if sanity - (texw * texh) != 0:
    raise newException(Exception, "Sanity: Number of pixels don't match: " & $sanity & " vs " & $(texw * texh))

  xnbstream.close()

  # testData(os.joinPath(dir, baseName & ".data"))

proc convertFromCrunch(originalMetaFile: string, binName: string) =
  echo "Converting .bin to .meta: ", binName

  let metain = newFileStream(binName, fmRead)
  defer: metain.close()

  let (dir, baseName, ext) = os.splitFile(binName)

  let metaout = newFileStream(os.joinPath(dir, baseName & ".meta"), fmWrite)
  defer: metaout.close()

  block:
    let metaorig = newFileStream(originalMetaFile, fmRead)
    defer: metaorig.close()

    let header_version = metaorig.readInt32()
    let header_args = metaorig.readString()
    # let header_hash = metaorig.readInt32()

    metaout.write(header_version)
    metaout.writeString(header_args)
    metaout.write(int32 0)

  let textures = metain.readInt16()
  metaout.write(textures)
  for i in 0..<textures:
    var textureName = metain.readLine()
    metaout.writeString(textureName)
    echo "texture: ", textureName

    convertPngToData(os.joinPath(dir, textureName & ".png"))

    os.removeFile(os.joinPath(dir, textureName & ".png"))

    let subtextures = metain.readInt16()
    metaout.write(subtextures)
    echo "  subtextures: ", subtextures
    for j in 0..<subtextures:

      let name = strutils.replace(metain.readLine(), "/", "\\")
      let x = metain.readInt16()
      let y = metain.readInt16()
      let w = metain.readInt16()
      let h = metain.readInt16()
      let fx = metain.readInt16()
      let fy = metain.readInt16()
      let fw = metain.readInt16()
      let fh = metain.readInt16()

      metaout.writeString(name)
      metaout.write(x)
      metaout.write(y)
      metaout.write(w)
      metaout.write(h)
      metaout.write(fx)
      metaout.write(fy)
      metaout.write(fw)
      metaout.write(fh)

      echo "    name: ", name

  echo "Created ", os.joinPath(dir, baseName & ".meta")


let atlases = ["Journal", "Gui", "Checkpoints", "Gameplay"]

for atlasName in atlases:

  echo "Processing texture atlas ", atlasName

  extract("input/" & atlasName & ".meta", "extracted/" & atlasName)

  os.createDir "output"

  # run crunch
  let errcode = osproc.waitForExit(startProcess(
    command="./crunch.bin",
    args=["output/" & atlasName, "extracted/" & atlasName, "--verbose", "--binary", "--trim", "--unique", "--size" & $newTextureSize, "--pad1", "--force"],
    options={osproc.poParentStreams, osproc.poUsePath}
  ))
  if errcode != 0:
    raise newException(Exception, "crunch failed to run! code " & $errcode)

  os.removeDir "extracted"

  convertFromCrunch(originalMetaFile="input/" & atlasName & ".meta", binName="output/" & atlasName & ".bin")

  os.removeFile("output/" & atlasName & ".bin")
  os.removeFile("output/" & atlasName & ".hash")
