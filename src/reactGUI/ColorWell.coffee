React = require './React-shim'
{classSet, requestAnimationFrame, cancelAnimationFrame} = require '../core/util'


getPosition = (element) =>
  x = 0
  y = 0
  while element
    x += (element.offsetLeft - element.scrollLeft + element.clientLeft)
    y += (element.offsetTop - element.scrollTop + element.clientTop)
    element = element.offsetParent
  {x, y}


parseHSLAString = (s) ->
  return "hsla(0, 0%, 0%, 0)" if s == 'transparent'
  return null unless s.substring(0, 4) == 'hsla'
  firstParen = s.indexOf('(')
  lastParen = s.indexOf(')')
  insideParens = s.substring(firstParen + 1, lastParen - firstParen + 4)
  components = (s.trim() for s in insideParens.split(','))
  return {
    hue: parseInt(components[0], 10)
    sat: parseInt(components[1].substring(0, components[1].length - 1), 10)
    light: parseInt(components[2].substring(0, components[2].length - 1), 10)
    alpha: parseFloat(components[3])
  }


getHSLAString = ({hue, sat, light, alpha}) ->
  "hsla(#{hue}, #{sat}%, #{light}%, #{alpha})"
getHSLString = ({hue, sat, light}) ->
  "hsl(#{hue}, #{sat}%, #{light}%)"


Slider = React.createFactory React.createClass
  displayName: 'Slider'
  getDefaultProps: -> {min: 0, max: 1, value: 1, onChange: ->}
  shouldComponentUpdate: (nextProps, nextState) -> true
    #return nextProps.value != @props.value
  render: ->
    {div} = React.DOM
    rangeSize = @props.max - @props.min
    pos = (@props.value - @props.min) / rangeSize
    posPercent = pos * 100 + '%'

    lineH = 4
    rad = 8
    m = 4
    fullH = m * 2 + rad * 2
    lineM = (fullH - lineH) / 2
    extraHorzM = 20

    getVal = (e) =>
      el = @refs.line.getDOMNode()
      parentPosition = getPosition(el)
      x = e.clientX - parentPosition.x
      positionInRange = x / el.clientWidth
      Math.max(@props.min, Math.min(@props.max, @props.min + rangeSize * positionInRange))

    update = (value) => @props.onChange(value)
    start = (e) =>
      e.stopPropagation()
      @setState({isMouseDown: true})
      console.profile()
    stop = (e) =>
      return unless @state?.isMouseDown
      console.profileEnd()
      update(getVal(e))
      @setState({isMouseDown: false})

    (div {
        style: {position: 'relative', width: '100%', height: fullH},
        onClick: (e) =>
          e.stopPropagation()
          update(getVal(e))
        onMouseMove: (e) =>
          return unless @state?.isMouseDown
          e.stopPropagation()
          value = getVal(e)
          cancelAnimationFrame(@state.animFrameId) if @state.animFrameId
          @setState({animFrameId: requestAnimationFrame => update(value)})
        onMouseDown: start
        onMouseUp: stop
        onMouseLeave: stop
        onMouseEnter: stop
      },
      (div {ref: 'line', style: {
        position: 'absolute',
        top: lineM, right: lineM + extraHorzM,
        bottom: lineM, left: lineM + extraHorzM,
        backgroundColor: 'black', borderRadius: lineH / 2}},
        (div {style: {
          borderRadius: rad,
          backgroundColor: '#aaa',
          border: '1px solid black',
          position: 'absolute',
          top: -(rad - lineH / 2),
          left: posPercent,
          width: rad * 2, height: rad * 2,
          transform: "translate(-#{rad}px,0px)"
        }})
      )
    )


ColorGrid = React.createFactory React.createClass
  displayName: 'ColorGrid'
  shouldComponentUpdate: (nextProps, nextState) -> true
    #@props.selectedColor != nextProps.selectedColor
  render: ->
    {div} = React.DOM
    (div {},
      @props.rows.map((row, ix) =>
        return (div \
          {
            className: 'color-row',
            key: ix,
            style: {width: 20 * row.length}
          },
          row.map((cellColor, ix2) =>
            {hue, sat, light, alpha} = cellColor
            colorString = getHSLAString(cellColor)
            colorStringNoAlpha = "hsl(#{hue}, #{sat}%, #{light}%)"
            className = classSet
              'color-cell': true
              'selected': @props.selectedColor == colorString
            (div \
              {
                className,
                onClick: (e) =>
                  @props.onChange(cellColor, colorString)
                  e.stopPropagation()
                style: {backgroundColor: colorStringNoAlpha}
                key: ix2
              }
            )
          )
        )
      )
    )


ColorWell = React.createClass
  displayName: 'ColorWell'
  getInitialState: ->
    colorString = @props.lc.colors[@props.colorName]
    hsla = getHSLAString(colorString)
    hsla ?= {alpha: 1, sat: 100, hue: 0, light: 50}
    {
      colorString,
      alpha: if hsla.alpha == null then 1 else hsla.alpha
      sat: if hsla.sat == null then 100 else hsla.alpha
      isPickerVisible: false,
      hsla: hsla
    }

  # our color state tracks lc's
  componentDidMount: ->
    @unsubscribe = @props.lc.on "#{@props.colorName}ColorChange", =>
      colorString = @props.lc.colors[@props.colorName]
      @setState({colorString})
      @setHSLAFromColorString(colorString)
  componentWillUnmount: -> @unsubscribe()

  setHSLAFromColorString: (c, forceSat=false) ->
    hsla = parseHSLAString(c)
    if hsla
      @setState({hsla, alpha: hsla.alpha, sat: hsla.sat})
    else
      @setState({hsla: null})

  closePicker: -> @setState({isPickerVisible: false})
  togglePicker: ->
    @setState({isPickerVisible: not @state.isPickerVisible})
    @setHSLAFromColorString(@state.colorString)

  setColor: (c) ->
    @setState({colorString: c})
    @setHSLAFromColorString(c)
    @props.lc.setColor(@props.colorName, c)

  setAlpha: (alpha) ->
    @setState({alpha})
    if @state.hsla
      hsla = @state.hsla
      hsla.alpha = alpha
      @setState({hsla})
      @setColor(getHSLAString(hsla))

  setSat: (sat) ->
    @setState({sat})
    if @state.hsla
      hsla = @state.hsla
      hsla.sat = sat
      @setState({hsla})
      @setColor(getHSLAString(hsla))

  render: ->
    {div, label, br} = React.DOM
    (div \
      {
        className: classSet({
          'color-well': true,
          'open': @state.isPickerVisible ,
        }),
        onMouseLeave: @closePicker
        onClick: @togglePicker
        style: {float: 'left', textAlign: 'center'}
      },
      (label {float: 'left'}, @props.label),
      (br {}),
      (div \
        {
          className: classSet
            'color-well-color-container': true
            'selected': @state.isPickerVisible
          style: {backgroundColor: 'white'}
        },
        (div {className: 'color-well-checker color-well-checker-top-left'}),
        (div {
          className: 'color-well-checker color-well-checker-bottom-right',
          style: {left: '50%', top: '50%'}
        }),
        (div \
          {
            className: 'color-well-color',
            style: {backgroundColor: @state.colorString}
          },
          " "
        ),
      ),
      @renderPicker()
    )

  renderPicker: ->
    {div, label} = React.DOM
    return null unless @state.isPickerVisible

    renderLabel = (text) =>
      (div {
        className: 'color-row label', key: text, style: {
          lineHeight: '20px'
          height: 16
        }
      }, text)

    renderColor = =>
      checkerboardURL = "#{lc.opts.imageURLPrefix}/checkerboard-8x8.png"
      (div {
        className: 'color-row', key: "color", style: {
          position: 'relative'
          backgroundImage: "url(#{checkerboardURL})"
          backgroundRepeat: 'repeat'
          height: 24
        }},
        (div {style: {
          position: 'absolute',
          top: 0, right: 0, bottom: 0, left: 0
          backgroundColor: @state.colorString
        }})
      )

    rows = []
    rows.push ({hue: 0, sat: 0, light: i, alpha: @state.alpha} for i in [0..100] by 10)
    for hue in [0, 30, 60, 90, 120, 150, 180, 210, 240, 270, 300, 330]
      rows.push ({hue, sat: @state.sat, light: i, alpha: @state.alpha} for i in [10..90] by 8)

    onSelectColor = (hsla, s) => @setColor(s)

    (div {className: 'color-picker-popup'},
      renderColor()
      renderLabel("alpha")
      (Slider {
        value: @state.alpha,
        onChange: (newValue) => @setAlpha(newValue)
      }),
      renderLabel("saturation")
      (Slider {
        value: @state.sat, max: 100,
        onChange: (newValue) => @setSat(newValue)
      }),
      (ColorGrid {rows, selectedColor: @state.colorString, onChange: onSelectColor})
    )


module.exports = ColorWell