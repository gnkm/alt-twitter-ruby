import { describe, it, expect } from 'vitest'
import { render, screen } from '@testing-library/react'

function TestComponent() {
  return <div>Hello, Testing Library!</div>
}

describe('React Testing Library', () => {
  it('should render a component', () => {
    render(<TestComponent />)
    expect(screen.getByText('Hello, Testing Library!')).toBeDefined()
  })
})
