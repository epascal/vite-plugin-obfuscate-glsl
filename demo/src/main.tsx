import React from 'react'
import ReactDOM from 'react-dom'
import { Root } from './Root'
import './styles.css'
import metalFragmentShader from './metal.fragment.glsl?raw';

console.log(metalFragmentShader);

ReactDOM.render(<Root />, document.getElementById('root'))
